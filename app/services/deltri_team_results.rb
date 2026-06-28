require "net/http"

# Given a Del-Tri team's public page URL, returns that team's season results
# (date, home/away, opponent, score, win/loss/tie) so a player can drill into
# any team in the standings and see how their matches went.
#
# Reads the "team_schedule" table, which lists one row per match as
# "MM/DD (H|A)  Opponent  our-opp". Rows without a real score (Holiday Break,
# Snow Date, unplayed) are skipped. Fetched live on demand — the site blocks
# non-browser requests, so we send browser-like headers.
class DeltriTeamResults
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  FETCH_TIMEOUT = 15

  Match = Struct.new(:date_label, :home, :opponent, :our, :opp, :result, keyword_init: true) do
    def score
      "#{our}-#{opp}"
    end

    def home_label
      home ? "Home" : "Away"
    end
  end

  def initialize(url)
    @url = url
  end

  def call
    parse(fetch(@url))
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

  def parse(html)
    table = html[/<table[^>]*class="[^"]*team_schedule[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    table.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      cells = row.scan(/<t[dh][^>]*>(.*?)<\/t[dh]>/im).map { |(c)| clean(c) }
      when_cell = cells.find { |c| c.match?(%r{\A\d{1,2}/\d{1,2}\s*\([HA]\)}i) }
      score_cell = cells.find { |c| c.match?(/\A\d+\s*-\s*\d+\z/) }
      next unless when_cell && score_cell

      date_label = when_cell[%r{\A(\d{1,2}/\d{1,2})}, 1]
      home = when_cell.match?(/\(H\)/i)
      opponent = cells.find { |c| c != when_cell && c != score_cell && c.match?(/[A-Za-z]/) }
      our, opp = score_cell.split("-").map { |n| n.strip.to_i }

      Match.new(
        date_label: date_label, home: home, opponent: opponent.to_s,
        our: our, opp: opp,
        result: (our > opp ? "W" : (our < opp ? "L" : "T"))
      )
    end
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end
end
