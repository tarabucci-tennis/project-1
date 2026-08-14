require "net/http"

# Auto-imports a USTA team's postseason (District → Sectional → National)
# matches from its public TennisRecord team page and tags them with a
# playoff_level, so they appear in the team's playoff segments and update on
# their own as TennisRecord ingests new results from TennisLink.
#
# TennisRecord lays the postseason out as separate "District Schedule" /
# "Sectional Schedule" / "National Schedule" tables under the regular season.
# We read only those (the regular season comes from the Google Sheet), so there
# is no overlap. Idempotent: re-running re-syncs each match.
class TennisrecordPlayoffs
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  FETCH_TIMEOUT = 20

  # TennisRecord marker => Court Report playoff level.
  STAGES = { "District" => "Districts", "Sectional" => "Sectionals", "National" => "Nationals" }.freeze

  # Court Report team name => its public TennisRecord team page.
  SOURCES = {
    "Kiss My Ace" => "https://www.tennisrecord.com/adult/teamprofile.aspx?teamname=Kiss My Ace&year=2026&s=4"
  }.freeze

  Result = Struct.new(:updated, :notes, keyword_init: true) do
    def to_s
      (updated.map { |t, n| "#{t}: #{n} postseason match(es)" } + notes).join(" · ")
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
      html = fetch(url)
      count = 0
      highest = nil

      STAGES.each do |marker, level|
        parse_stage(html, marker).each do |m|
          upsert_match(team, m, level)
          highest = level
          count += 1
        end
      end

      # Reflect the furthest round reached so the right segment shows.
      team.update_column(:playoff_level, highest) if highest && team.playoff_level != highest
      updated[team.name] = count
    rescue StandardError => e
      notes << "#{team_name}: #{e.class} — #{e.message}"
    end

    Result.new(updated: updated, notes: notes)
  end

  private

  def upsert_match(team, m, level)
    match = team.matches.detect { |x| x.match_date.to_date == m[:date] && normalize(x.opponent) == normalize(m[:opponent]) }
    match ||= team.matches.new(match_date: Time.zone.local(m[:date].year, m[:date].month, m[:date].day, 9, 0), opponent: m[:opponent])
    result = m[:ours] > m[:theirs] ? "win" : (m[:ours] < m[:theirs] ? "loss" : "tie")
    match.assign_attributes(
      location:      m[:site].presence,
      playoff_level: level,
      home_away:     match.home_away.presence,
      score_summary: "#{m[:ours]}-#{m[:theirs]}",
      result:        result
    )
    match.save!
  end

  # Returns [{ date: Date, opponent:, site:, ours:, theirs: }] for one stage.
  def parse_stage(html, marker)
    section = html[/#{marker}\s*Schedule(.*?)(?:(?:District|Sectional|National|Local)\s*Schedule|Player Stats|\z)/mi, 1] || ""
    section.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      cells = row.scan(/<td[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }
      di = cells.index { |c| c.match?(%r{\A\d{1,2}/\d{1,2}/\d{4}}) }
      next unless di
      score = cells.find { |c| c.match?(/\A\d+\s*-\s*\d+\z/) }
      next unless score
      date = parse_date(cells[di])
      next unless date
      ours, theirs = score.split("-").map { |n| n.strip.to_i }
      { date: date, opponent: cells[di + 2].to_s, site: cells[di + 3].to_s, ours: ours, theirs: theirs }
    end
  end

  def fetch(url)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = UA
      req["Accept"] = "text/html,application/xhtml+xml"
      http.request(req)
    end
    raise "HTTP #{res.code}" unless res.code.to_i == 200

    res.body.to_s
  end

  def parse_date(str)
    m = str.to_s.match(%r{(\d{1,2})/(\d{1,2})/(\d{4})})
    return nil unless m
    Date.new(m[3].to_i, m[1].to_i, m[2].to_i)
  rescue ArgumentError
    nil
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
