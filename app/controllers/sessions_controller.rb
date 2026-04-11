class SessionsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user
      session[:user_id] = user.id

      if session[:pending_join_code].present?
        team = TennisTeam.find_by(join_code: session.delete(:pending_join_code))
        if team && !team.team_memberships.exists?(user: user)
          TeamMembership.create!(user: user, tennis_team: team, role: "player")
        end
      end

      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "No account found for that email."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "You've been signed out."
  end
end
