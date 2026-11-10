require "net/http"
require "uri"
require "date"

# Pulls tennis events from a user's Google Calendar (or any calendar) by its
# public/secret iCal (.ics) link — matches, clinics and friendlies — and stores
# the ones that look like tennis as ExternalEvents, so they can sit on the
# Court Report calendar next to league matches.
#
# No login or password: we only ever read the one .ics URL the user pastes in.
# "Tennis" is decided by keyword (the user chose keyword-filtering), including
# the user's own team names. Everything is re-pulled on each run, so deleting an
# event in Google removes it here too. Plain string parsing, no gems.
class GoogleCalendarImport
  FETCH_TIMEOUT = 15

  # Base tennis words; each user's own team names are added on top.
  KEYWORDS = [
    "tennis", "match", "clinic", "friendly", "friendlies", "court", "usta",
    "bux-mont", "buxmont", "del-tri", "deltri", "drill", "lesson", "league",
    "doubles", "singles", "ntrp", "racquet", "racket", "round robin",
    "practice", "lineup", "deuce", "volley", "rally"
  ].freeze

  Result = Struct.new(:imported, :scanned, :error, keyword_init: true) do
    def to_s
      error ? "error: #{error}" : "kept #{imported} of #{scanned} events"
    end
  end

  def self.sync_all
    total = 0
    User.where.not(ical_url: [ nil, "" ]).find_each do |u|
      total += new(u).call.imported.to_i
    rescue StandardError => e
      Rails.logger.error("[GoogleCalendarImport] user #{u.id}: #{e.class} — #{e.message}")
    end
    "imported #{total} tennis events"
  end

  def initialize(user)
    @user = user
  end

  def call
    url = normalize(@user.ical_url)
    return Result.new(imported: 0, scanned: 0, error: "No calendar link") if url.blank?

    events = parse(fetch(url))
    kept = events.select { |e| tennis?(e) }

    ExternalEvent.transaction do
      @user.external_events.delete_all
      kept.each do |e|
        @user.external_events.create!(
          title: e[:summary].presence || "Tennis", starts_at: e[:starts_at],
          ends_at: e[:ends_at], location: e[:location], all_day: e[:all_day], uid: e[:uid]
        )
      end
    end
    Result.new(imported: kept.size, scanned: events.size)
  rescue StandardError => e
    Result.new(imported: 0, scanned: 0, error: e.message)
  end

  # Parse an .ics string into event hashes. Public so it can be unit-tested
  # without a network call.
  def parse(ics)
    unfolded = ics.to_s.gsub(/\r?\n[ \t]/, "") # iCal folds long lines
    unfolded.scan(/BEGIN:VEVENT(.*?)END:VEVENT/m).filter_map do |block|
      b = block[0]
      start = dt_line(b, "DTSTART")
      next nil unless start
      starts_at, all_day = start
      ends_at = (dt_line(b, "DTEND") || [])[0]
      {
        summary:  unescape(prop(b, "SUMMARY")),
        location: unescape(prop(b, "LOCATION")),
        uid:      prop(b, "UID"),
        starts_at: starts_at, ends_at: ends_at, all_day: all_day,
        haystack: "#{prop(b, 'SUMMARY')} #{prop(b, 'LOCATION')} #{prop(b, 'DESCRIPTION')}".downcase
      }
    end
  end

  def tennis?(event)
    hay = event[:haystack].to_s
    keywords.any? { |k| hay.include?(k) }
  end

  private

  def keywords
    @keywords ||= (KEYWORDS + @user.member_teams.map { |t| t.name.to_s.downcase })
                  .reject { |k| k.to_s.strip.empty? }.uniq
  end

  def normalize(url)
    url.to_s.strip.sub(/\Awebcal:/i, "https:")
  end

  def fetch(url)
    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "CourtReport/1.0 (+https://yourcourtreport.com)"
      http.request(req)
    end
    raise "That link returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    res.body.to_s.dup.force_encoding("UTF-8").scrub
  end

  def prop(block, name)
    m = block.match(/^#{name}(?:;[^:\n]*)?:(.*)$/i)
    m ? m[1].strip : nil
  end

  def unescape(str)
    str.to_s.gsub(/\\n/i, " ").gsub(/\\,/, ",").gsub(/\\;/, ";").gsub(/\\\\/, "\\").strip
  end

  # Returns [Time, all_day?] or nil. Handles DATE (all-day), UTC (…Z) and
  # local/floating date-times.
  def dt_line(block, name)
    m = block.match(/^#{name}([^:\n]*):\s*([0-9TZ]+)/i)
    return nil unless m
    params, val = m[1], m[2]
    if params =~ /VALUE=DATE/i || val.match?(/\A\d{8}\z/)
      y, mo, d = val[0, 4].to_i, val[4, 2].to_i, val[6, 2].to_i
      return nil if mo.zero? || d.zero?
      return [ Time.new(y, mo, d), true ]
    end
    dm = val.match(/\A(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?/)
    return nil unless dm
    y, mo, d, h, mi, s = dm[1..6].map(&:to_i)
    t = dm[7] ? Time.new(y, mo, d, h, mi, s, "+00:00") : Time.new(y, mo, d, h, mi, s)
    [ t, false ]
  end
end
