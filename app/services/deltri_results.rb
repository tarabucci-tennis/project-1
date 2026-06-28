require "net/http"
require "cgi"

# Pulls a team's line-by-line match results from its public tenniscores page
# (Del-Tri, WITAP/Inter-Club, etc.) so players can tap a match in Court Report
# and see who played, the set scores, and who won — the same expandable Results
# card USTA teams get from the Google Sheet.
#
# Driven by each team's `tenniscores_url`:
#   1. Read the page's standings table; the team's own row links to one
#      printable scorecard per match (cell id encodes home h* / away a*). The
#      team's row is found by the team= id in its URL, or by name as a fallback.
#   2. For each scorecard, parse the date and the doubles lines. Each line is
#      two rows — visiting on top, home on the bottom — so "our" row is the
#      bottom one when we're home, top when away.
#   3. A set is marked won with a "bold-text" class. Line winner = more sets
#      won, ties broken by total games. This reconciles with the printed total.
#   4. Each parsed line becomes a row in the shape SheetResultsImporter already
#      consumes, so all the match-matching, lineup-publishing and idempotency
#      logic is reused. Matches are created from the scorecard if missing.
class DeltriResults
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
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

    TennisTeam.where.not(tenniscores_url: [ nil, "" ]).find_each do |team|
      base = base_of(team.tenniscores_url)
      page = fetch(team.tenniscores_url)
      links = team_match_links(page, team)
      if links.empty?
        notes << "No match links found for #{team.name}"
        next
      end
      division = division_names(page)

      rows = []
      links.each do |link|
        card = fetch("#{base}/#{link[:path]}")
        parsed = parse_scorecard(card, home: link[:home])
        next unless parsed[:date] && parsed[:lines].any?

        opponent = resolve_opponent(card, division, team.name)
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
        notes << "#{team.name} scorecard: #{e.class} — #{e.message}"
      end

      outcome = SheetResultsImporter.new(team.reload).import(rows)
      updated[team.name] = outcome.to_s
    rescue StandardError => e
      notes << "#{team.name}: #{e.class} — #{e.message}"
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

  # The team's own row in the standings table. Each weekly cell links to a
  # printable scorecard and its id starts with "h" (home) or "a" (away).
  # We pick the row by the team= id in the team's URL (exact, name-independent);
  # if the URL has no team= id (e.g. a division-standings link), fall back to
  # matching the team name.
  def team_match_links(html, team)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    want_id = team_param(team.tenniscores_url)

    row = table.scan(/<tr[^>]*>(.*?)<\/tr>/im).map { |(r)| r }.detect do |r|
      cell = r[/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s
      next false if cell.blank?
      if want_id
        team_param_from_href(cell[/href="([^"]+)"/i, 1]) == want_id
      else
        normalize(clean(cell)) == normalize(team.name)
      end
    end
    return [] unless row

    row.scan(/<td[^>]*id="([ha])\d+"[^>]*>.*?href="(print_match\.php\?sch=[^"]+)"/im).map do |(ha, href)|
      { path: href.gsub("&amp;", "&"), home: ha == "h" }
    end
  end

  def division_names(html)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    table.scan(/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }.reject(&:blank?).uniq
  end

  def resolve_opponent(card, division, team_name)
    header = clean(card[/(?:Division \d+|Cup \w+|Match)(.*?)(?:Line 1|1 Doubles)/im, 1].to_s)
    header = clean(card)[0, 200] if header.blank?
    candidates = division.reject { |n| normalize(n) == normalize(team_name) }
    candidates.sort_by { |n| -n.length }.detect { |n| header.include?(n) }
  end

  # Returns { date: Date, lines: [{ number:, our:[names], opp:[names], score:, result: }] }
  def parse_scorecard(html, home:)
    body = html.gsub(/<(script|style)[^>]*>.*?<\/\1>/mi, "")
    date_str = clean(body)[/[A-Z][a-z]+ \d{1,2}, \d{4}/]
    date = date_str ? (Date.parse(date_str) rescue nil) : nil

    lines = body.scan(/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im).filter_map do |(t)|
      number = line_number(t)
      next unless number
      trs = t.scan(/<tr[^>]*>(.*?)<\/tr>/im).map { |(r)| parse_line_row(r) }
      next if trs.size < 2

      top, bot = trs[0], trs[1]
      our, opp = home ? [ bot, top ] : [ top, bot ]
      { number: number,
        our: names(our[:players]), opp: names(opp[:players]),
        score: zip_score(our[:sets], opp[:sets]),
        result: line_result(our[:sets], opp[:sets]) }
    end

    { date: date, lines: lines }
  end

  # Line label is "Line N" (Del-Tri) or "N Doubles" / "N Singles" (WITAP).
  def line_number(table_html)
    head = clean(table_html[/<t[dh][^>]*>(.*?)<\/t[dh]>/im, 1].to_s)
    (head[/\bLine\s+(\d)/i, 1] || head[/\A\s*(\d)\s*(?:Doubles|Singles)/i, 1])&.to_i
  end

  def parse_line_row(row)
    players = nil
    sets = []
    row.scan(/<t[dh]([^>]*)>(.*?)<\/t[dh]>/im).each do |(attrs, inner)|
      cls = attrs[/class="([^"]*)"/i, 1].to_s
      txt = clean(inner)
      if cls.include?("card_names")
        players = inner
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

  # "1 Anh Bixby / 1 Rachel Miller" (Del-Tri) or
  # "Joanne Steinberg 1 Cup 6 / Christi Neilly (S) Cup 6" (WITAP)
  # => ["Anh Bixby", "Rachel Miller"] / ["Joanne Steinberg", "Christi Neilly"].
  # Strips leading seed numbers, "(S)" sub markers, and the "Cup N" league tag.
  def names(cell)
    clean(cell).split("/").map do |part|
      p = part.gsub(/&#?\w+;?/, " ").gsub(/[↑↓]/, " ").gsub(/\A\s*\d+\s*/, "")
      lead = p[/\A[^\d(]+/] || p              # name = leading text before a digit/paren/Cup tag
      lead.gsub(/\(\s*s\b[^)]*\)?/i, "").gsub(/\bCup\b.*\z/i, "").gsub(/\s+/, " ").strip
    end.reject(&:blank?)
  end

  def team_param(url)
    team_param_from_href(url)
  end

  def team_param_from_href(href)
    return nil if href.blank?
    val = href.to_s[/team=([^"&]+)/i, 1]
    return nil unless val
    CGI.unescape(val)
  end

  def base_of(url)
    uri = URI(url)
    "#{uri.scheme}://#{uri.host}"
  rescue StandardError
    "https://deltri.tenniscores.com"
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
