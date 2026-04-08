class TennisTeamsController < ApplicationController
  before_action :require_login

  def show
    @team = TennisTeam.find(params[:id])
    @user = @team.user
  end
end
