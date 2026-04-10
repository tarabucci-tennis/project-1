class ProfilesController < ApplicationController
  def show
    return redirect_to login_path unless current_user

    @user  = current_user
    @teams = current_user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @teams = current_user.tennis_teams.order(start_date: :desc) if @teams.empty?
    @stats = @user.tennis_stats.chronological
  end
end
