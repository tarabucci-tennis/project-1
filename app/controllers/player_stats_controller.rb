class PlayerStatsController < ApplicationController
  before_action :require_login

  def show
    @team = Team.find(params[:team_id])
    @player = @team.team_players.find(params[:id])
    @analytics = PlayerAnalytics.new(@player)
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end
end
