class TeamsController < ApplicationController
  before_action :require_login
  before_action :set_team, only: [ :show ]

  def index
    @teams = Team.includes(:team_players, :captain).order(:name)
  end

  def show
    @matches = @team.scheduled_matches.chronological.includes(:player_availabilities, :lineup_slots)
    @players = @team.team_players.ordered
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end

  def set_team
    @team = Team.find(params[:id])
  end
end
