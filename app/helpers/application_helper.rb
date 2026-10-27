module ApplicationHelper
  # Small line icons (stroke = currentColor) used instead of emoji, so the UI
  # reads as one clean, professional set. icon(:home), icon(:pin, size: 14)…
  ICON_PATHS = {
    home:    '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
    lineups: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4h6v3H9z"/><path d="M9 11h6M9 15h6"/>',
    trophy:  '<path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4"/><path d="M12 13v4M9 20h6"/>',
    users:   '<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M16 5.5a3 3 0 0 1 0 5.5M18 20a6 6 0 0 0-3-5.2"/>',
    chat:    '<path d="M4 5h16v11H9l-5 4z"/>',
    search:  '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
    user:    '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    pin:     '<path d="M12 21s-6-5.6-6-11a6 6 0 0 1 12 0c0 5.4-6 11-6 11z"/><circle cx="12" cy="10" r="2.2"/>',
    chart:   '<path d="M5 20V10M12 20V4M19 20v-7"/>',
    alert:   '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.5v.01"/>',
    calendar: '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    check:   '<circle cx="12" cy="12" r="8"/><path d="M8.5 12.5l2.5 2.5 4.5-5"/>',
    ball:    '<circle cx="12" cy="12" r="8"/><path d="M7 5.8c2.4 3.4 2.4 9 0 12.4M17 5.8c-2.4 3.4-2.4 9 0 12.4"/>',
    trend:   '<path d="M4 17l5-5 4 3 7-8"/><path d="M15 7h5v5"/>'
  }.freeze

  def icon(name, size: 18, css: nil)
    content_tag(:svg, ICON_PATHS.fetch(name).html_safe, width: size, height: size, viewBox: "0 0 24 24",
                fill: "none", stroke: "currentColor", "stroke-width": 1.8, "stroke-linecap": "round",
                "stroke-linejoin": "round", "aria-hidden": "true", class: [ "cr-icon", css ].compact.join(" "))
  end

  # Returns the current user's teams grouped by league category.
  # Used by the shared league nav partial. Returns an empty hash when
  # there's no logged-in user.
  # Teams grouped by the league they actually play in, keyed by the name a
  # player would recognise ("USTA", "Inter-Club", "Del-Tri", "Bux-Mont").
  # Grouping used to be by league_category, which put every local league in
  # one "Local" bucket that the UI then hardcoded as "Del-Tri" — so a second
  # local league showed up under the wrong name. Ordering is stable: USTA
  # first, then Inter-Club, then local leagues alphabetically.
  def current_user_teams_by_league
    return {} unless current_user

    teams = current_user.member_teams.to_a
    teams = current_user.tennis_teams.to_a if teams.empty?
    TennisTeam.group_by_league(teams)
  end

  # TennisRecord.com profile URL for a player by name. TennisRecord is
  # a public, login-free aggregator of USTA match results + computed
  # dynamic ratings. We deep-link every player name in Court Report to
  # their TennisRecord profile so captains and players can instantly see
  # opponent rating, win %, and recent match history — data that USTA
  # TennisLink hides behind personal-account login.
  def tennis_record_url(name_or_user)
    name = name_or_user.respond_to?(:name) ? name_or_user.name : name_or_user.to_s
    return "#" if name.blank?
    "https://www.tennisrecord.com/adult/profile.aspx?playername=#{CGI.escape(name)}"
  end

  # TennisRecord.com match history URL for a player. Shows line-by-line
  # results (date, flight, line, partner, opponents, score) for the given
  # calendar year. Defaults to the current year.
  def tennis_record_match_history_url(name_or_user, year: Date.current.year)
    name = name_or_user.respond_to?(:name) ? name_or_user.name : name_or_user.to_s
    return "#" if name.blank?
    "https://www.tennisrecord.com/adult/matchhistory.aspx?year=#{year}&playername=#{CGI.escape(name)}&mt=0&lt=0&yr=0"
  end

  # Convenience wrapper: renders a player name as a link that opens
  # their TennisRecord profile in a new tab. Accepts either a User
  # record or a plain name string; forwards any html_options (class,
  # style, etc.) to link_to.
  def link_to_tennis_record(name_or_user, html_options = {})
    name = name_or_user.respond_to?(:name) ? name_or_user.name : name_or_user.to_s
    return name if name.blank?
    link_to name,
            tennis_record_url(name_or_user),
            html_options.merge(target: "_blank", rel: "noopener", title: "View #{name} on TennisRecord")
  end

  # Geometry for the semicircular "rating meter" gauge on a player profile.
  # The band is the 0.5-wide NTRP level the given rating falls in (e.g. 3.40 →
  # the 3.0001–3.5000 band); the needle points to where the rating sits inside
  # it. Pass the live Court Report dynamic rating. Returns nil when there's no
  # rating to place. Coordinates are for a 260×150 viewBox with the hub at
  # (130,130), radius 88 for the needle.
  def rating_meter_data(rating:)
    return nil if rating.blank?

    value = rating.to_f
    hi = (value * 2).ceil / 2.0          # round up to the nearest 0.5
    hi = value + 0.5 if hi <= value      # exactly on a boundary → its own band top
    lo = (hi - 0.5).round(4)

    position = ((value - lo) / (hi - lo)).clamp(0.0, 1.0)
    angle = (180 - position * 180) * Math::PI / 180.0
    {
      lo: lo,
      hi: hi,
      value: value,
      position: position,
      title: format("%.1f Rating Meter", hi),
      band_label: format("%.4f – %.4f", lo + 0.0001, hi),
      needle_x: (130 + 88 * Math.cos(angle)).round(2),
      needle_y: (130 - 88 * Math.sin(angle)).round(2)
    }
  end

  # The friendly invite text (the link itself is shared separately):
  #   🎾 KMA
  #   📅 Sat, Oct 17 · 1:00 – 2:30 PM
  #   📍 Aronimink Golf Club
  #   3600 St Davids Rd
  #   Newtown Square, PA 19073
  #
  #   Can you play? Add your name here. Every 4 names = 1 court, so we'll add
  #   courts if more people join. This link always shows who's playing and the lineup:
  def friendly_invite_text(friendly)
    lines = [ "🎾 #{friendly.title}", "📅 #{friendly.starts_at.strftime('%a, %b %-d')} · #{friendly.time_label}" ]
    lines.concat(place_lines(friendly.place))
    lines << "" << "Can you play? Add your name here. Every 4 names = 1 court, so we'll add courts " \
                   "if more people join. This link always shows who's playing and the lineup:"
    lines.join("\n")
  end

  # 📍 name / street / town lines for a Club or Friendly::Place (no map link:
  # Tara wants texts short; people paste the address into Waze or Maps).
  def place_lines(place)
    return [] unless place
    place.name.present? ? [ "📍 #{place.name}", *place.address_lines ] : [ "📍 #{place.address_lines.first}", *place.address_lines.drop(1) ]
  end

  # A friendly's lineup as plain text for a group chat.
  def friendly_lineup_text(friendly)
    lines = [ "#{friendly.title} — #{friendly.starts_at.strftime('%a, %b %-d')} · #{friendly.time_label}" ]
    lines.concat(place_lines(friendly.place))
    friendly.lineup_sets.first(friendly.sets_count).each_with_index do |set, i|
      lines << "" << "Set #{i + 1}"
      Array(set["courts"]).each_with_index do |(a, b, c, d), ci|
        lines << "Ct #{ci + 1}: #{a} + #{b} vs #{c} + #{d}"
      end
      lines << "Sitting out: #{set['sitting'].join(', ')}" if Array(set["sitting"]).any?
    end
    lines << "" << "Waitlist: #{friendly.waitlist.map(&:name).join(', ')}" if friendly.waitlist.any?
    lines.join("\n")
  end

  # Google Calendar "add event" link for a friendly (until its end time, else 2 hours). Times are
  # written without a zone, like the match links, so Google uses the viewer's.
  def friendly_google_calendar_url(friendly, share_url: nil)
    fmt = "%Y%m%dT%H%M%S"
    start = friendly.starts_at
    details = [ "Tennis friendly organized by #{friendly.organizer.name}.", friendly.notes.presence, share_url ].compact.join("\n")
    params = {
      action: "TEMPLATE",
      text: "🎾 #{friendly.title}",
      dates: "#{start.strftime(fmt)}/#{(friendly.ends_at || start + 2.hours).strftime(fmt)}",
      location: friendly.place&.full.to_s,
      details: details
    }
    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end

  # Where a match is played, as one line: the league club (Bux-Mont /
  # Del-Tri), else the listed site, else our home club for a home match.
  # Where a match is, as a venue-like object for the 📍 block: the saved
  # club, else the typed location split into name / address.
  def match_place_block(match)
    return match.venue if match.venue
    text = match_place(match)
    return unless text
    name, rest = text.split(/,\s*/, 2)
    Friendly::Place.new(name: name, address: rest)
  end

  def match_place(match)
    return match.venue.full if match.venue
    return match.location if match.location.present?
    return unless match.home?
    team = match.tennis_team
    [ team.home_court, team.home_court_address ].compact_blank.uniq.join(", ").presence
  end

  # Plain-text summary of a match to text a sub: one detail per line, the
  # address stacked like on the site, no map link (too much text). Readable
  # without an account.
  #
  #   🎾 Advantage Us vs. Frog Hollow Platinum
  #   📅 Mon, Oct 19 · 10:30 am
  #   Away · Bux-Mont
  #   👕 Wear: All black
  #
  #   📍 Frog Hollow Racquet Club
  #   2115 Weber Road
  #   Lansdale, PA 19446
  #
  #   Join Court Report free: yourcourtreport.com/signup
  # A team clinic / friendly (TeamEvent) as a text to share, same layout as
  # a match.
  def team_event_share_text(event)
    lines = [ "🎾 #{event.kind_label}: #{event.title}",
              "📅 #{[ event.event_date.strftime('%a, %b %-d'), event.start_time.presence ].compact.join(' · ')}",
              event.tennis_team.name ]
    if event.location.present?
      name, rest = event.location.split(/,\s*/, 2)
      lines << ""
      lines.concat(place_lines(Friendly::Place.new(name: name, address: rest)))
    end
    lines << "" << "Join Court Report free: #{signup_url.sub(%r{\Ahttps?://(www\.)?}, '')}"
    lines.join("\n")
  end

  # Google Calendar link for a team clinic / friendly. Its start time is
  # typed text ("6:00 PM"); when it can't be read the event is all-day.
  def team_event_google_calendar_url(event)
    start = (Time.zone.parse("#{event.event_date} #{event.start_time}") if event.start_time.present? rescue nil)
    dates = if start
      fmt = "%Y%m%dT%H%M%S"
      "#{start.strftime(fmt)}/#{(start + 2.hours).strftime(fmt)}"
    else
      "#{event.event_date.strftime('%Y%m%d')}/#{(event.event_date + 1).strftime('%Y%m%d')}"
    end
    params = {
      action: "TEMPLATE",
      text: "🎾 #{event.kind_label}: #{event.title}",
      dates: dates,
      location: event.location.to_s,
      details: [ event.tennis_team.name, event.notes.presence ].compact.join("\n")
    }
    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end

  def match_share_text(match)
    team = match.tennis_team
    side = match.home? ? "Home" : ("Away" if match.away?)
    lines = [ "🎾 #{team.name} vs. #{match.opponent}",
              "📅 #{[ match.match_date.strftime('%a, %b %-d'), match.match_time.presence ].compact.join(' · ')}",
              [ side, team.league_label ].compact.join(" · ") ]
    lines << "👕 Wear: #{team.team_colors}" if team.team_colors.present?

    if (venue = match.venue)
      lines << "" << "📍 #{venue.name}"
      lines.concat(venue.address_lines)
    elsif (place = match_place(match))
      lines << "" << "📍 #{place}"
    end

    lines << "" << "Join Court Report free: #{signup_url.sub(%r{\Ahttps?://(www\.)?}, '')}"
    lines.join("\n")
  end

  # The "Can you play?" text a captain sends for one match (the link is shared separately).
  def match_poll_text(match)
    team = match.tennis_team
    side = match.home? ? "Home" : ("Away" if match.away?)
    lines = [ "🎾 #{team.name} vs. #{match.opponent}",
              "📅 #{[ match.match_date.strftime('%a, %b %-d'), match.match_time.presence, side ].compact.join(' · ')}" ]
    if (venue = match.venue)
      lines << "📍 #{venue.name}"
    elsif (place = match_place(match))
      lines << "📍 #{place}"
    end
    lines << "" << "Can you play? Tap your name, then Yes or No (no account needed):"
    lines.join("\n")
  end

  # A match's lineup as text for the team chat: the match details, then one
  # line per court ("1D: Alison Vachris & Tara Bucci"). Open lines show "—".
  def lineup_share_text(match)
    team = match.tennis_team
    side = match.home? ? "Home" : ("Away" if match.away?)
    lines = [ "🎾 #{team.name} vs. #{match.opponent}",
              "📅 #{[ match.match_date.strftime('%a, %b %-d'), match.match_time.presence, side ].compact.join(' · ')}" ]
    if (venue = match.venue)
      lines << "📍 #{venue.name}"
      lines.concat(venue.address_lines)
    elsif (place = match_place(match))
      lines << "📍 #{place}"
    end

    lines << "" << "Lineup"
    slots = match.lineup ? match.lineup.lineup_slots.includes(:user).sort_by { |s| [ s.line_type == "singles" ? 0 : 1, s.position.to_i, s.id ] } : []
    slots.group_by(&:line_label).each do |label, group|
      names = group.map { |s| s.user&.name }.compact
      lines << "#{label}: #{names.any? ? names.join(' & ') : '—'}"
    end
    lines.join("\n")
  end

  def google_calendar_url(match)
    team_name = match.tennis_team.name
    title = "#{team_name} vs. #{match.opponent}"
    location = match.venue&.full || match.tennis_team.home_court.presence || match.location.to_s

    start_time = match.match_date
    end_time = start_time + 2.hours

    date_format = "%Y%m%dT%H%M%S"
    dates = "#{start_time.strftime(date_format)}/#{end_time.strftime(date_format)}"

    details = "Tennis match: #{title}"
    details += "\n#{match.match_time}" if match.match_time.present?
    details += "\n#{match.location}" if match.location.present?

    params = {
      action: "TEMPLATE",
      text: title,
      dates: dates,
      location: location,
      details: details
    }

    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end

  # Past Seasons: a season's year, "2026" from "Spring 2026" or "2025-26"
  # from "Fall/Winter 2025-26"; falls back to the team's start year.
  def archive_year(team)
    label = team.season_name.to_s
    m = label.match(/(\d{4})(?:\s*[-–\/]\s*(\d{2,4}))?/)
    return m[2] ? "#{m[1]}-#{m[2][-2..]}" : m[1] if m
    team.start_date&.year&.to_s || "Other"
  end

  # Teams grouped by year, newest year first.
  def archive_by_year(teams)
    teams.group_by { |t| archive_year(t) }.sort_by { |year, _| year == "Other" ? "" : year }.reverse
  end

  # The season without its year ("Spring", "Fall/Winter"), for rows under a year.
  def archive_season_part(team)
    part = team.season_name.to_s.sub(/\s*\(completed\)\s*/i, "")
                .sub(/\s*\d{4}(?:\s*[-–\/]\s*\d{2,4})?\s*/, " ").squish
    part.presence || "Season"
  end
end
