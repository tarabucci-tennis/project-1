require "net/http"

# Imports players' personal match history (from their tenniscores player pages)
# into player_matches, so their results — including teams they only subbed on —
# show on their profile. Idempotent per (user, site).
#
# Player pages are discovered two ways:
#   1. The roster of any team that has a `tenniscores_url`: each roster entry
#      links to that player's page. Roster names are matched to Court Report
#      users by name, so a player's history (across every division/cup they
#      played, subs included) auto-fills with nothing to paste.
#   2. An explicit link a user saved on their profile (`deltri_player_url`).
class DeltriPlayerImport
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  FETCH_TIMEOUT = 20

  Result = Struct.new(:imported, :notes, keyword_init: true) do
    def to_s
      (imported.map { |name, n| "#{name}: #{n} matches" } + notes).join(" · ")
    end
  end

  # League label per site host, for display. Only a fallback now — the first
  # place we look is the league_name saved on a team that plays on that host,
  # so a new league labels itself correctly with no code change.
  LEAGUES = {
    "deltri.tenniscores.com"  => "Del-Tri",
    "witap.tenniscores.com"   => "Inter-Club",
    "buxmont.tenniscores.com" => "Bux-Mont"
  }.freeze

  # Del-Tri and Bux-Mont are different leagues that happen to share a
  # platform, so matches must never be filed under each other's name.
  def self.league_for(host)
    return "Tennis" if host.blank?

    from_team = TennisTeam.where.not(tenniscores_url: [ nil, "" ])
                          .where.not(league_name: [ nil, "" ])
                          .find { |t| host_of(t.tenniscores_url) == host }
    from_team&.league_name || LEAGUES[host] || "Tennis"
  end

  def self.sync_all
    imported = {}
    notes = []
    seen = {}

    gather_sources.each do |src|
      key = "#{src[:user].id}:#{src[:host]}"
      next if seen[key]
      seen[key] = true

      r = new(src[:user]).import_from(src[:url], src[:host])
      r.imported.each { |name, n| imported[name] = (imported[name] || 0) + n }
      notes.concat(r.notes)
    end

    Result.new(imported: imported, notes: notes)
  end

  # [{ user:, url:, host: }] — explicit profile links plus roster-resolved ones.
  def self.gather_sources
    list = []

    User.where.not(deltri_player_url: [ nil, "" ]).find_each do |u|
      list << { user: u, url: u.deltri_player_url, host: host_of(u.deltri_player_url) }
    end

    TennisTeam.where.not(tenniscores_url: [ nil, "" ]).find_each do |team|
      host = host_of(team.tenniscores_url)
      roster_links(team.tenniscores_url).each do |entry|
        user = User.where("LOWER(name) = ?", entry[:name].downcase).first
        next unless user
        list << { user: user, url: entry[:url], host: host }
      end
    rescue StandardError
      next
    end

    list
  end

  # [{ name:, url: }] from a team page's roster table.
  def self.roster_links(team_url)
    html = fetch(team_url)
    base = base_of(team_url)
    roster = html[/<table[^>]*class="[^"]*team_roster_table[^"]*"[^>]*>(.*?)<\/table>/im, 1] || html
    roster.scan(/<a[^>]*href="([^"]*player\.php[^"]*)"[^>]*>(.*?)<\/a>/im).filter_map do |(href, label)|
      name = label.gsub(/<[^>]+>/, "").gsub(/\s*\d+\s*\z/, "").gsub(/\s+/, " ").strip
      next if name.blank?
      { name: name, url: href.start_with?("http") ? href : "#{base}#{href.gsub('&amp;', '&')}" }
    end
  end

  def self.host_of(url)
    URI(url).host.to_s
  rescue StandardError
    ""
  end

  def self.base_of(url)
    uri = URI(url)
    "#{uri.scheme}://#{uri.host}"
  rescue StandardError
    ""
  end

  def self.fetch(url, limit = 4)
    raise "Too many redirects" if limit <= 0
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = UA
      req["Accept"] = "text/html,application/xhtml+xml"
      http.request(req)
    end
    case res
    when Net::HTTPRedirection
      loc = res["location"]
      loc = "#{uri.scheme}://#{uri.host}#{loc}" unless loc.start_with?("http")
      fetch(loc, limit - 1)
    when Net::HTTPSuccess then res.body.to_s
    else raise "HTTP #{res.code}"
    end
  end

  def initialize(user)
    @user = user
  end

  # Back-compat single-arg entry point (explicit profile link).
  def call
    return Result.new(imported: {}, notes: []) if @user.deltri_player_url.blank?
    import_from(@user.deltri_player_url, self.class.host_of(@user.deltri_player_url))
  end

  def import_from(url, host)
    rows = DeltriPlayerHistory.new(url).call
    league = self.class.league_for(host)
    seen = []
    rows.each do |row|
      next if row[:source_key].blank?
      pm = @user.player_matches.find_or_initialize_by(source: host, source_key: row[:source_key])
      pm.assign_attributes(
        league: league,
        division: row[:division], date_label: row[:date_label], played_on: row[:played_on],
        match_label: row[:match_label], line_label: row[:line_label],
        partner: row[:partner], opponents: row[:opponents],
        score: row[:score], result: row[:result]
      )
      pm.save!
      seen << pm.id
    end
    @user.player_matches.where(source: host).where.not(id: seen).delete_all if seen.any?

    Result.new(imported: { @user.name => rows.size }, notes: [])
  rescue StandardError => e
    Result.new(imported: {}, notes: [ "#{@user.name}: #{e.class} — #{e.message}" ])
  end
end
