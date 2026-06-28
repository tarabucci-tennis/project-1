require "net/http"

# Pulls Legacy 2's line-by-line match results from the public Del-Tri site
# (deltri.tenniscores.com) so players can tap a match in Court Report and see
# who played, the set scores, and who won — the same expandable Results card
# that USTA teams get from the Google Sheet.
#
# How it works:
#   1. Read the division standings page; the team's own row links to one
#      printable scorecard per match, and the cell id encodes home (h*) / away (a*).
#   2. For each scorecard, parse the date and the 6 doubles lines. Each line is
#      two rows — visiting team on top, home team on the bottom — so "our" row is
#      the bottom one when we're home, the top one when we're away.
#   3. A set is marked won with a "bold-text" class. Line winner = more sets won,
#      ties broken by total games (Del-Tri is a games/points league). This
#      reconciles exactly with the match's printed line total.
#   4. Each parsed line becomes a row in the shape SheetResultsImporter already
#      consumes, so all the match-matching, lineup-publishing and idempotency
#      logic is reused. Matches are created from the scorecard if they don't
#      already exist on the team's schedule.
#
# The site blocks non-browser requests, so we send browser-like headers.
class DeltriResults
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze

  # Court Report team name => its Del-Tri division-standings URL.
  SOURCES = {
    "Legacy 2" => "https://deltri.tenniscores.com/?mod=nndz-TjJiOWtOR3QzTU4yakRrY1NjN1FMcGpx&did=nndz-WXllNndRPT0%3D"
  }.freeze

  BASE = "https://deltri.tenniscores.com/".freeze
  FETCH_TIMEOUT = 20

  Result = Struct.new(:updated, :notes, keyword_init: true) do
    def to_s
      parts = updated.map { |team, o| "#{team}: #{o}" }
      (parts + notes).join(" · ")
    end
  end

  def call
    updated = {}
    notes = []

    SOURCES.each do |team_name, url|
      team = TennisTeam.where("LOWER(name) = ?", team_name.downcase).first
      unless team
        notes << "No Court Report team “#{team_name}”"
        next
      end

      standings = fetch(url)
      links = team_match_links(standings, team_name)
      if links.empty?
        notes << "No match links found for #{team_name}"
        next
      end
      division = division_names(standings)

      rows = []
      links.each do |link|
        card = fetch(BASE + link[:path])
        parsed = parse_scorecard(card, home: link[:home])
        next unless parsed[:date] && parsed[:lines].any?

        opponent = resolve_opponent(card, division, team_name)
        match = ensure_match(team, parsed[:date], opponent, link[:home])
        parsed[:lines].each do |ln|
          rows << {
            match_date: parsed[:date],
            opponent:   match.opponent,
            line:       "##{ln[:number]} Doubles",
            player_1:   ln[:our][0], player_2: ln[:our][1],
            opponent_1: ln[:opp][0], opponent_2: ln[:opp][1],
            score:      ln[:score], result: ln[:result]
          }
        end
      rescue StandardError => e
        notes << "#{team_name} scorecard: #{e.class} — #{e.message}"
      end

      outcome = SheetResultsImporter.new(team.reload).import(rows)
      updated[team.name] = outcome.to_s
    rescue StandardError => e
      notes << "#{team_name}: #{e.class} — #{e.message}"
    end

    Result.new(updated: updated, notes: notes)
  end

  private

  def fetch(url)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = UA
      req["Accept"] = "text/html,application/xhtml+xml"
      req["Accept-Language"] = "en-US,en;q=0.9"
      http.request(req)
    end
    raise "HTTP #{res.code}" unless res.code.to_i == 200

    res.body.to_s
  end

  # From the standings page, the team's own row. Each weekly cell links to a
  # printable scorecard and its id starts with "h" (home) or "a" (away).
  def team_match_links(html, team_name)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    row = table.scan(/<tr[^>]*>(.*?)<\/tr>/im).map { |(r)| r }.detect do |r|
      name = clean(r[/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s)
      normalize(name) == normalize(team_name)
    end
    return [] unless row

    row.scan(/<td[^>]*id="([ha])\d+"[^>]*>.*?href="(print_match\.php\?sch=[^"]+)"/im).map do |(ha, href)|
      { path: href.gsub("&amp;", "&"), home: ha == "h" }
    end
  end

  # The list of teams in this division, from the standings table (used to read
  # the opponent name out of a scorecard's mashed-together header).
  def division_names(html)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    table.scan(/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }.reject(&:blank?).uniq
  end

  def resolve_opponent(card, division, team_name)
    header = clean(card[/Division \d+(.*?)Line 1/im, 1].to_s)
    candidates = division.reject { |n| normalize(n) == normalize(team_name) }
    candidates.sort_by { |n| -n.length }.detect { |n| header.include?(n) }
  end

  # Returns { date: Date, lines: [{ number:, our:[names], opp:[names], score:, result: }] }
  def parse_scorecard(html, home:)
    body = html.gsub(/<(script|style)[^>]*>.*?<\/\1>/mi, "")
    date_str = clean(body)[/[A-Z][a-z]+ \d{1,2}, \d{4}/]
    date = date_str ? (Date.parse(date_str) rescue nil) : nil

    lines = body.scan(/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im).filter_map do |(t)|
      number = t[/Line\s+(\d)/i, 1]
      next unless number
      trs = t.scan(/<tr[^>]*>(.*?)<\/tr>/im).map { |(r)| parse_line_row(r) }
      next if trs.size < 2

      top, bot = trs[0], trs[1]
      our, opp = home ? [ bot, top ] : [ top, bot ]
      { number: number.to_i,
        our: names(our[:players]), opp: names(opp[:players]),
        score: zip_score(our[:sets], opp[:sets]),
        result: line_result(our[:sets], opp[:sets]) }
    end

    { date: date, lines: lines }
  end

  # One <tr> of a line: pull the players cell and the numeric set cells (each
  # tagged with whether it's the won set, via the "bold-text" class).
  def parse_line_row(row)
    players = nil
    sets = []
    row.scan(/<t[dh]([^>]*)>(.*?)<\/t[dh]>/im).each do |(attrs, inner)|
      cls = attrs[/class="([^"]*)"/i, 1].to_s
      txt = clean(inner)
      if cls.include?("card_names")
        players = txt
      elsif cls.include?("pts2") && txt.match?(/\A\d+\z/)
        sets << { v: txt.to_i, won: cls.include?("bold-text") }
      end
    end
    { players: players, sets: sets }
  end

  def zip_score(our_sets, opp_sets)
    n = [ our_sets.size, opp_sets.size ].max
    (0...n).map do |i|
      o = our_sets[i]&.dig(:v) || 0
      p = opp_sets[i]&.dig(:v) || 0
      "#{o}-#{p}"
    end.join(" ").presence
  end

  def line_result(our_sets, opp_sets)
    our_won = our_sets.count { |s| s[:won] }
    opp_won = opp_sets.count { |s| s[:won] }
    return (our_won > opp_won ? "W" : "L") if our_won != opp_won

    # Tie on sets (or no winner markers): Del-Tri is games-based, so total games decide.
    our_sets.sum { |s| s[:v] } >= opp_sets.sum { |s| s[:v] } ? "W" : "L"
  end

  def ensure_match(team, date, opponent, home)
    match = team.matches.detect { |m| m.match_date.to_date == date }
    return match if match

    team.matches.create!(
      match_date: Time.zone.local(date.year, date.month, date.day, 12, 0),
      opponent: opponent || "Opponent",
      home_away: home ? "home" : "away",
      notes: home ? "Home match" : "Away match"
    )
  end

  # "1 Anh Bixby / 1 Rachel Miller" => ["Anh Bixby", "Rachel Miller"]
  # Strips leading seeding digits and trailing "(S)" sub markers.
  def names(cell)
    cell.to_s.split("/").map do |part|
      part.gsub(/\(S\)/i, "").gsub(/\A\s*\d+\s*/, "").gsub(/\s+/, " ").strip
    end.reject(&:blank?)
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
