class JoinsController < ApplicationController
  def show
    @team = TennisTeam.find_by(join_code: params[:code])
    unless @team
      redirect_to root_path, alert: "That join link isn't valid."
      return
    end

    unless current_user
      # Save the join code in session so the signup / sign-in flow
      # can consume it and auto-add the team.
      session[:pending_join_code] = params[:code]
      redirect_to signup_path,
                  notice: "Create your account to join #{@team.name} — already have one? Sign in instead."
      return
    end

    if @team.team_memberships.exists?(user: current_user)
      redirect_to team_path(@team), notice: "You're already on #{@team.name}!"
      return
    end

    TeamMembership.create!(user: current_user, tennis_team: @team, role: "player")
    redirect_to team_path(@team), notice: "You've joined #{@team.name}!"
  end
end
