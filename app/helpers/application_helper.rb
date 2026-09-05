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

  # Geometry for the semicircular "rating meter" gauge on a player profile,
  # styled after TennisRecord's. The needle sits within the 0.5-wide NTRP band
  # (e.g. a 4.0 rating → the 3.5001–4.0000 band); the live Court Report Rating
  # (or, if absent, the band midpoint) decides where in the band it points.
  # Returns nil when there's no NTRP to anchor the band. Coordinates are for a
  # 260×150 viewBox with the hub at (130,130), radius 88 for the needle.
  def rating_meter_data(ntrp:, dynamic: nil)
    return nil if ntrp.blank?

    ntrp = ntrp.to_f
    hi = ntrp
    lo = (ntrp - 0.5).round(4)
    value = dynamic.present? ? dynamic.to_f : (lo + hi) / 2.0

    position = (value - lo) / (hi - lo)
    position = 0.0 if position < 0
    position = 1.0 if position > 1

    angle = (180 - position * 180) * Math::PI / 180.0
    {
      lo: lo,
      hi: hi,
      value: value,
      position: position,
      title: format("%.1f Rating Meter", ntrp),
      band_label: format("%.4f – %.4f", lo + 0.0001, hi),
      needle_x: (130 + 88 * Math.cos(angle)).round(2),
      needle_y: (130 - 88 * Math.sin(angle)).round(2)
    }
  end

  def google_calendar_url(match)
    team_name = match.tennis_team.name
    title = "#{team_name} vs. #{match.opponent}"
    location = match.tennis_team.home_court.presence || match.location.to_s

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
