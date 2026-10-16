module ApplicationHelper
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
  #   Map: maps.google.com/?q=...
  #
  #   Add your name if you can play, and check this link for updates:
  def friendly_invite_text(friendly)
    lines = [ "🎾 #{friendly.title}", "📅 #{friendly.starts_at.strftime('%a, %b %-d')} · #{friendly.time_label}" ]
    lines.concat(place_lines(friendly.place))
    lines << "" << "Add your name if you can play, and check this link for updates:"
    lines.join("\n")
  end

  # 📍 name / street / town / Map lines for a Club or Friendly::Place.
  def place_lines(place)
    return [] unless place
    out = place.name.present? ? [ "📍 #{place.name}", *place.address_lines ] : [ "📍 #{place.address_lines.first}", *place.address_lines.drop(1) ]
    out << "Map: #{short_map_link(place.address.presence || place.name)}"
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
  def match_place(match)
    return match.venue.full if match.venue
    return match.location if match.location.present?
    return unless match.home?
    team = match.tennis_team
    [ team.home_court, team.home_court_address ].compact_blank.uniq.join(", ").presence
  end

  # Plain-text summary of a match to text a sub: one detail per line, the
  # address stacked like on the site, short links. Readable without an account.
  #
  #   🎾 Advantage Us vs. Frog Hollow Platinum
  #   📅 Mon, Oct 19 · 10:30 am
  #   Away · Bux-Mont
  #   👕 Wear: All black
  #
  #   📍 Frog Hollow Racquet Club
  #   2115 Weber Road
  #   Lansdale, PA 19446
  #   Map: maps.google.com/?q=2115+Weber+Road+Lansdale+PA+19446
  #
  #   Join Court Report free: yourcourtreport.com/signup
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
      map_query = venue.address.presence || venue.name
    elsif (place = match_place(match))
      lines << "" << "📍 #{place}"
      map_query = place
    end
    lines << "Map: #{short_map_link(map_query)}" if map_query

    lines << "" << "Join Court Report free: #{signup_url.sub(%r{\Ahttps?://(www\.)?}, '')}"
    lines.join("\n")
  end

  # A short Google Maps search link for an address (no https://, + for spaces),
  # e.g. maps.google.com/?q=2115+Weber+Road+Lansdale+PA+19446
  def short_map_link(query)
    words = query.to_s.gsub(/[^A-Za-z0-9#&\- ]/, " ").split
    "maps.google.com/?q=#{words.map { |w| ERB::Util.url_encode(w) }.join('+')}"
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
end
