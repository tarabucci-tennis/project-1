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
end
