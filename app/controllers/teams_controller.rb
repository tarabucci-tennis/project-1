class TeamsController < ApplicationController
  before_action :require_login

  def index
    @teams = current_user.tennis_teams.order(start_date: :desc)
  end

  def show
    @team = current_user.tennis_teams.find_by(id: params[:id])

    unless @team
      redirect_to teams_path, alert: "Team not found."
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
