require "net/http"

# Reads a team's roster from its public tenniscores page (Bux-Mont, Del-Tri,
# Inter-Club): each player's line/seed number, name, captain mark, the
# league's own rating and her W-L-T this season. Read live for the opponent
# pop-up and cached for a few hours; nothing is saved.
#
# The rating shown is that LEAGUE's number, not the player's USTA rating, so
# callers must label it as such.
class TenniscoresRoster
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  FETCH_TIMEOUT = 15

  Player = Struct.new(:group, :seed, :name, :role, :rating, :wins, :losses, :ties, keyword_init: true)

  def initialize(url)
    @url = url
  end

  def call
    html = Rails.cache.fetch([ "tenniscores-roster", @url ], expires_in: 6.hours) { fetch(@url) }
    parse(html)
  end

  # Skips the cache — for the nightly roster sync.
  def fetch_fresh
    parse(fetch(@url))
  end

  def parse(html)
    table = html[/<table[^>]*class="[^"]*team_roster_table[^"]*"[^>]*>(.*?)<\/table>/im, 1] || ""
    group = "Players"
    table.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      if (heading = row[/<th[^>]*class="[^"]*player_col\b[^"]*"[^>]*>(.*?)<\/th>/im, 1])
        group = clean(heading)
        next
      end
      cells = row.scan(/<td[^>]*>(.*?)<\/td>/im).map { |(c)| c }
      next if cells.size < 5

      name = clean(cells[0][/<a[^>]*>(.*?)<\/a>/im, 1].to_s)
      next if name.empty?

      lead = clean(cells[0])
      Player.new(
        group:  group,
        seed:   lead[/\A(\d+)/, 1]&.to_i,
        name:   name,
        role:   lead[/\((CC|C)\)/, 1],
        rating: clean(cells[1]).presence,
        wins:   clean(cells[2]).to_i,
        losses: clean(cells[3]).to_i,
        ties:   clean(cells[4]).to_i
      )
    end
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

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end
end
