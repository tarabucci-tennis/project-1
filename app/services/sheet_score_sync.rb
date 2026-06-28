require "net/http"
require "csv"

# Pulls match results straight from Tara's public Google Sheet and imports
# them via SheetResultsImporter (results + posted lineups + standings).
#
# The sheet has one tab per team. We fetch each tab as CSV via the public
# gviz endpoint (works with "anyone with the link" sharing, no API key),
# parse by column NAME (tabs vary slightly in columns), then route each row
# to its Court Report team using the row's own `team` column.
#
# Re-running is safe — the importer upserts, it does not duplicate.
class SheetScoreSync
  SHEET_ID = "15tSu5Ytoly4AU_YBrzVHsV0DL4yz2XSlN3Dk3eqe7Ak".freeze

  # Exact tab names to read. (Baby Got Backhands has no Court Report team yet,
  # so its rows are simply skipped with a note.)
  TABS = [
    "USTA 40+ KMA",
    "USTA 18+ Pour Decisions",
    "USTA 18+ Baby Got Backhands",
    "Inter-Club PCC #2"
  ].freeze

  FETCH_TIMEOUT = 20

  Result = Struct.new(:summaries, :notes, keyword_init: true) do
    def to_s
      parts = summaries.map { |team, o| "#{team}: #{o.matches_updated} match(es)" }
      parts.concat(notes)
      parts.join(" · ")
    end
  end

  def call
    rows  = []
    notes = []

    TABS.each do |tab|
      rows.concat(fetch_tab(tab))
    rescue StandardError => e
      notes << "Couldn't read “#{tab}” (#{e.message})"
    end

    summaries = {}
    rows.group_by { |r| r[:team].to_s.strip }.each do |team_name, team_rows|
      next if team_name.blank?
      team = find_team(team_name)
      unless team
        notes << "No Court Report team named “#{team_name}” — skipped"
        next
      end
      summaries[team.name] = SheetResultsImporter.new(team).import(team_rows)
    end

    Result.new(summaries: summaries, notes: notes)
  end

  private

  def fetch_tab(name)
    uri = URI("https://docs.google.com/spreadsheets/d/#{SHEET_ID}/gviz/tq")
    uri.query = URI.encode_www_form(tqx: "out:csv", sheet: name)

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "CourtReport/1.0 (+https://yourcourtreport.com)"
      http.request(req)
    end
    raise "HTTP #{res.code}" unless res.code.to_i == 200

    CSV.parse(res.body.to_s, headers: true).map do |row|
      {
        match_date: row["match_date"],
        opponent:   row["opponent"],
        line:       row["line"],
        player_1:   row["player_1"],
        player_2:   row["player_2"],
        opponent_1: row["opponent_1"],
        opponent_2: row["opponent_2"],
        score:      row["score"],
        result:     row["result"],
        team:       row["team"]
      }
    end
  end

  def find_team(name)
    TennisTeam.where("LOWER(name) = ?", name.downcase).first
  end
end
