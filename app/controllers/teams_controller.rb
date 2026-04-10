class TeamsController < ApplicationController
  before_action :require_login

  def index
    all_teams = current_user.member_teams.includes(:matches, :team_memberships)

    @teams_by_league = {
      "USTA"        => all_teams.select { |t| t.league_category == "USTA" },
      "Inter-Club"  => all_teams.select { |t| t.league_category == "Inter-Club" },
      "Local"       => all_teams.select { |t| t.league_category == "Local" }
    }

    # Fallback: include teams Tara owns even if she has no team_membership row
    if @teams_by_league.values.flatten.empty? && current_user.tennis_teams.any?
      owned = current_user.tennis_teams.order(start_date: :desc)
      @teams_by_league = {
        "USTA"        => owned.select { |t| t.league_category == "USTA" },
        "Inter-Club"  => owned.select { |t| t.league_category == "Inter-Club" },
        "Local"       => owned.select { |t| t.league_category == "Local" }
      }
    end
  end

  def show
    @team = TennisTeam.includes(team_memberships: :user, matches: {}).find_by(id: params[:id])

    unless @team
      redirect_to teams_path, alert: "Team not found."
      return
    end

    unless member_of?(@team) || current_user.admin?
      redirect_to teams_path, alert: "You're not a member of that team."
      return
    end

    @captain          = @team.captain
    @roster           = @team.team_memberships.includes(:user).sort_by { |m| [ m.captain? ? 0 : 1, m.user.name.to_s.downcase ] }
    @upcoming_matches = @team.matches.where("match_date >= ?", Time.current).order(match_date: :asc)
    @past_matches     = @team.matches.where("match_date < ?", Time.current).order(match_date: :desc)
    @player_count     = @team.team_memberships.count
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def member_of?(team)
    team.team_memberships.exists?(user: current_user) || team.user_id == current_user.id
  end
end
