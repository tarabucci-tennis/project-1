require "net/http"

# Pulls division standings from a team's public tenniscores page (Del-Tri,
# WITAP/Inter-Club, or any tenniscores site) and stores the other teams in the
# league as DivisionTeam rows, so the Standings tab shows the real league table
# instead of zeros. Idempotent.
#
# Driven by each team's `tenniscores_url` (set in the DB), so adding a new
# league is just a matter of saving a link — no code change. The site blocks
# non-browser requests, so we send browser-like headers.
class DeltriStandings
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze

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

    TennisTeam.where.not(tenniscores_url: [ nil, "" ]).find_each do |team|
      @base = base_of(team.tenniscores_url)
      rows = fetch_standings(team.tenniscores_url)
      if rows.empty?
        notes << "No standings rows read for #{team.name}"
        next
      end
      updated[team.name] = upsert(team, rows)
    rescue StandardError => e
      notes << "#{team.name}: #{e.class} — #{e.message}"
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

  # Returns [{ name:, points:, wins:, losses:, ties:, line_wins:, games_lost:,
  # source_url: }] in standings order.
  #
  # Team name comes from <td class="team2">, the team's own page link from that
  # same cell (for the opponent drill-down), and the record from <td class="pts2">.
  # Two record formats are in the wild on tenniscores and both are supported:
  #
  #   Del-Tri / Inter-Club  pts2 = "68"     — a points total (games won)
  #   Bux-Mont              pts2 = "3/1/0"  — W/L/T, with Line Wins and Games
  #                                           Lost in the trailing <td class="std">
  #
  # Before this, a non-numeric pts2 failed the integer check and the whole
  # division was skipped, so a W/L/T league imported zero rows.
  def parse(html)
    table = html[/<table[^>]*class="[^"]*standings-table2[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    table.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      team_cell = row[/<td[^>]*class="[^"]*\bteam2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s
      name   = clean(team_cell)
      record = clean(row[/<td[^>]*class="[^"]*\bpts2\b[^"]*"[^>]*>(.*?)<\/td>/im, 1].to_s)
      next if name.blank?

      stats = row.scan(/<td[^>]*class="[^"]*\bstd\b[^"]*"[^>]*>(.*?)<\/td>/im)
                 .map { |(c)| clean(c) }

      base = { name: name, source_url: absolutize(team_cell[/href="([^"]+)"/i, 1]) }

      if (m = record.match(/\A(\d+)\s*\/\s*(\d+)(?:\s*\/\s*(\d+))?\z/))
        base.merge(wins: m[1].to_i, losses: m[2].to_i, ties: m[3].to_i,
                   line_wins: stats[0].to_i, games_lost: stats[1].to_i,
                   points: stats[0].to_i)
      elsif record.match?(/\A\d+\z/)
        base.merge(wins: record.to_i, losses: 0, ties: 0,
                   line_wins: 0, games_lost: 0, points: record.to_i)
      end
    end
  end

  # Stores every team in the division (including the team itself) so the
  # Standings tab can render the real league table. Prunes teams that dropped.
  def upsert(team, rows)
    seen = []
    rows.each_with_index do |row, i|
      dt = team.division_teams.find_or_initialize_by(name: row[:name])
      # In a points league (Del-Tri, Inter-Club) wins IS the points total —
      # that's what the Standings tab renders. In a W/L/T league (Bux-Mont)
      # they're a real record, with line wins carried in points.
      dt.wins = row[:wins]
      dt.losses = row[:losses]
      dt.ties = row[:ties]
      dt.points = row[:points]
      dt.games_lost = row[:games_lost]
      dt.position = i + 1
      dt.source_url = row[:source_url] if row[:source_url].present?
      dt.save!
      seen << dt.id
    end
    team.division_teams.where.not(id: seen).delete_all if seen.any?
    rows.size
  end

  def base_of(url)
    uri = URI(url)
    "#{uri.scheme}://#{uri.host}"
  rescue StandardError
    "https://deltri.tenniscores.com"
  end

  def absolutize(href)
    return nil if href.blank?
    href = href.gsub("&amp;", "&")
    href.start_with?("http") ? href : "#{@base}#{href}"
  end

  def clean(str)
    str.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").strip
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
