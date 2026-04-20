module ApplicationHelper
  # Returns the current user's teams grouped by league category.
  # Used by the shared league nav partial. Returns an empty hash when
  # there's no logged-in user.
  def current_user_teams_by_league
    return {} unless current_user

    teams = current_user.member_teams.to_a
    teams = current_user.tennis_teams.to_a if teams.empty?
    teams.group_by(&:league_category)
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
