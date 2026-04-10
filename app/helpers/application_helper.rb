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
