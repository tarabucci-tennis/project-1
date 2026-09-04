require "net/http"

# Imports a team's season schedule from its public tenniscores team page
# (Bux-Mont, Del-Tri, WITAP/Inter-Club — the markup is the same product).
#
# Driven by each team's `tenniscores_url`, so adding a league is a matter of
# saving a link. Idempotent: re-running updates the same rows rather than
# duplicating them, and it never touches a match that already has a result
# entered, so a schedule refresh can't wipe scores a captain typed in.
#
# Opt-in per team via `schedule_sync`. Legacy 2 and PCC have hand-entered
# schedules going back a full season; nothing automated goes near them until
# each has been checked against its own league site.
#
# Bye weeks, holiday breaks and the playoff placeholder are skipped — they're
# not matches, and rendering them as "vs. Bye" clutters the schedule.
class TenniscoresSchedule
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze

  FETCH_TIMEOUT = 20

  # Rows whose "opponent" is really a filler week, not a team.
  NON_MATCH = /\A(bye|holiday break|playoffs?|tba|open)\b/i

  Result = Struct.new(:created, :updated, :skipped, :notes, keyword_init: true) do
    def to_s
      parts = []
      created.each { |team, n| parts << "#{team}: +#{n} new" }
      updated.each { |team, n| parts << "#{team}: #{n} updated" }
      parts << "#{skipped} bye/break rows skipped" if skipped.positive?
      (parts + notes).join(" · ")
    end
  end

  def self.sync_all
    created = {}
    updated = {}
    skipped = 0
    notes   = []

    TennisTeam.where(schedule_sync: true).where.not(tenniscores_url: [ nil, "" ]).find_each do |team|
      r = new(team).call
      created[team.name] = r.created[team.name] if r.created[team.name].to_i.positive?
      updated[team.name] = r.updated[team.name] if r.updated[team.name].to_i.positive?
      skipped += r.skipped
      notes.concat(r.notes)
    end

    Result.new(created: created, updated: updated, skipped: skipped, notes: notes)
  end

  def initialize(team)
    @team = team
  end

  def call
    rows = parse(fetch(@team.tenniscores_url))
    if rows.empty?
      return empty_result([ "No schedule rows read for #{@team.name}" ])
    end

    created = 0
    updated = 0
    skipped = rows.count { |r| r[:filler] }

    rows.reject { |r| r[:filler] }.each do |row|
      match = @team.matches.where(match_date: row[:date].all_day).first

      # A result has been entered — leave the row alone entirely. The site is
      # the authority on the fixture list, never on scores we already have.
      next if match&.result.present?

      if match
        match.assign_attributes(attrs_for(row))
        updated += 1 if match.changed?
        match.save!
      else
        @team.matches.create!(attrs_for(row))
        created += 1
      end
    end

    Result.new(created: { @team.name => created }, updated: { @team.name => updated },
               skipped: skipped, notes: [])
  rescue StandardError => e
    empty_result([ "#{@team.name}: #{e.class} — #{e.message}" ])
  end

  private

  def attrs_for(row)
    {
      match_date: starts_at(row),
      match_time: row[:time],
      opponent:   row[:opponent],
      home_away:  row[:home_away],
      location:   row[:home_away] == "home" ? @team.home_court.presence : nil
    }.compact
  end

  # Fold the posted start time into match_date so schedules sort by when the
  # match actually starts, not just by day. match_time keeps the label the
  # league site printed ("10:30 am") for display.
  def starts_at(row)
    t = row[:time].to_s.match(/\A(\d{1,2}):(\d{2})\s*([ap])m?/i)
    return row[:date].to_time unless t

    hour = t[1].to_i % 12
    hour += 12 if t[3].downcase == "p"
    row[:date].to_time.change(hour: hour, min: t[2].to_i)
  end

  def empty_result(notes)
    Result.new(created: {}, updated: {}, skipped: 0, notes: notes)
  end

  # The team page's schedule table. Each row looks like:
  #
  #   <tr class="team_schedule_tr">
  #     <td class="date team_schedule_td_date">09/14</td>
  #     <td class="... team_schedule_td_ha">(H)</td>   (absent on bye/break rows)
  #     <td>Upper Dublin</td>
  #     <td>10:30 am</td>
  #   </tr>
  #
  # Dates carry no year because the season straddles New Year, so we start at
  # the team's season year and roll forward whenever the month goes backwards.
  def parse(html)
    table = html[/<table[^>]*class="[^"]*team_schedule[^"]*"[^>]*>(.*?)<\/table>/im, 1] || html
    year  = season_start_year
    prev_month = nil

    table.scan(/<tr[^>]*class="[^"]*team_schedule_tr[^"]*"[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      cells = row.scan(/<td[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }
      raw_date = cells.shift.to_s
      md = raw_date.match(%r{\A(\d{1,2})/(\d{1,2})})
      next unless md

      month = md[1].to_i
      year += 1 if prev_month && month < prev_month
      prev_month = month

      date = safe_date(year, month, md[2].to_i)
      next unless date

      home_away = raw_date.match?(/\(H\)/i) ? "home" : (raw_date.match?(/\(A\)/i) ? "away" : nil)
      opponent  = cells.find { |c| c.present? && !c.match?(/\A\d{1,2}:\d{2}/) }.to_s
      time      = cells.find { |c| c.match?(/\A\d{1,2}:\d{2}/) }

      { date: date, opponent: opponent, time: time, home_away: home_away,
        filler: opponent.blank? || opponent.match?(NON_MATCH) }
    end
  end

  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue ArgumentError
    nil
  end

  # Season year for the first row on the page. A team's saved start_date is
  # the source of truth; otherwise assume a season that opens in the second
  # half of the calendar year (Aug onwards) belongs to the current year.
  def season_start_year
    return @team.start_date.year if @team.start_date.present?
    Date.current.month >= 8 ? Date.current.year : Date.current.year - 1
  end

  def fetch(url)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
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
    str.gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ").gsub("&amp;", "&")
       .gsub(/\s+/, " ").strip
  end
end
