require "net/http"

# Pulls a team's division standings from the public Del-Tri site
# (deltri.tenniscores.com) and stores the other teams in the league as
# DivisionTeam rows, so the Standings tab shows the real league table
# instead of zeros. Idempotent.
#
# The site blocks non-browser requests, so we send browser-like headers.
# Standings come as a simple table: Team | Pts | Weeks | (weekly scores...).
class DeltriStandings
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze

  # Court Report team name => its Del-Tri division-standings URL.
  SOURCES = {
    "Legacy 2" => "https://deltri.tenniscores.com/?mod=nndz-TjJiOWtOR3QzTU4yakRrY1NjN1FMcGpx&did=nndz-WXllNndRPT0%3D"
  }.freeze

  FETCH_TIMEOUT = 20

  Result = Struct.new(:updated, :notes, keyword_init: true) do
    def to_s
      parts = updated.map { |team, n| "#{team}: #{n} opponents" }
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
      rows = fetch_standings(url)
      if rows.empty?
        notes << "No standings rows read for #{team_name}"
        next
      end
      updated[team.name] = upsert(team, rows)
    rescue StandardError => e
      notes << "#{team_name}: #{e.class} — #{e.message}"
    end

    Result.new(updated: updated, notes: notes)
  end

  private

  def fetch_standings(url)
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

    parse(res.body.to_s)
  end

  # Returns [{ name:, points: }] in standings order.
  #
  # The standings table (class "standings-table2 division_standings") has one
  # <tr> per team. The team name lives in <td class="team2"><a>NAME</a></td>
  # and its points in <td class="pts2">NN</td>. Targeting those classes is more
  # robust than counting cells, because each row also has a long tail of weekly
  # per-match score cells that also contain digits.
  def parse(html)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    table.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      team_cell = row[/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s
      name   = clean(team_cell)
      points = clean(row[/<td[^>]*class="[^"]*\bpts2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s)
      next if name.blank? || !points.match?(/\A\d+\z/)
      href = team_cell[/href="([^"]+)"/i, 1]
      { name: name, points: points.to_i, source_url: absolutize(href) }
    end
  end

  def absolutize(href)
    return nil if href.blank?
    href = href.gsub("&amp;", "&")
    href.start_with?("http") ? href : "https://deltri.tenniscores.com#{href}"
  end

  # Stores every team in the division (including the team itself) so the
  # Standings tab can render the real league table — points come straight
  # from Del-Tri rather than being re-derived from entered match data.
  # Any previously-stored division team that's no longer in the table is
  # removed, so a re-run reflects the live standings exactly.
  def upsert(team, rows)
    seen = []
    rows.each_with_index do |row, i|
      dt = team.division_teams.find_or_initialize_by(name: row[:name])
      dt.wins = row[:points] # Local/Del-Tri standings render dt.wins as points
      dt.losses = 0
      dt.position = i + 1
      dt.source_url = row[:source_url] if row[:source_url].present?
      dt.save!
      seen << dt.id
    end
    team.division_teams.where.not(id: seen).delete_all if seen.any?
    rows.size
  end

  def clean(str)
    str.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").strip
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
