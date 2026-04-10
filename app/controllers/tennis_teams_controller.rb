class TennisTeamsController < ApplicationController
  before_action :require_login

  def show
    @team = TennisTeam.find(params[:id])
    @matches = @team.tennis_matches.chronological
    @record = {
      wins: @matches.count { |m| m.result == "W" },
      losses: @matches.count { |m| m.result == "L" }
    }
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end
end
