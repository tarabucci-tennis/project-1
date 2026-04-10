class ProfilesController < ApplicationController
  before_action :require_login

  # GET /profile — your own profile
  def show
    @user  = current_user
    @teams = current_user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @teams = current_user.tennis_teams.order(start_date: :desc) if @teams.empty?
    @stats = @user.tennis_stats.chronological
    @is_self = true
    @shared_teams = []
    render :player
  end

  # GET /players/:id — teammate's profile
  def player
    @user = User.find_by(id: params[:id])
    unless @user
      redirect_to teams_path, alert: "Player not found."
      return
    end

    @teams = @user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @stats = @user.tennis_stats.chronological
    @is_self = (@user.id == current_user.id)

    # Find teams you share with this player
    my_team_ids = current_user.member_teams.pluck(:id)
    their_team_ids = @user.member_teams.pluck(:id)
    shared_ids = my_team_ids & their_team_ids
    @shared_teams = TennisTeam.where(id: shared_ids).order(start_date: :desc)
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end
end
