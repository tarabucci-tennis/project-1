class SessionsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user.nil?
      flash.now[:alert] = "No account found for that email."
      return render :new, status: :unprocessable_entity
    end

    # If user has a password set, require it
    if user.password_digest.present?
      if user.authenticate(params[:password].to_s)
        session[:user_id] = user.id
        handle_pending_join(user)
        redirect_to root_path, notice: "Welcome back, #{user.name}!"
      else
        flash.now[:alert] = "Incorrect password."
        render :new, status: :unprocessable_entity
      end
    else
      # Legacy user without password — let them in but prompt to set one
      session[:user_id] = user.id
      handle_pending_join(user)
      redirect_to root_path, notice: "Welcome back! Please set a password from your profile."
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "You've been signed out."
  end

  private

  def handle_pending_join(user)
    if session[:pending_join_code].present?
      team = TennisTeam.find_by(join_code: session.delete(:pending_join_code))
      if team && !team.team_memberships.exists?(user: user)
        TeamMembership.create!(user: user, tennis_team: team, role: "player")
      end
    end
  end
end
