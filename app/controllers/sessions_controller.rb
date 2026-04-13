class SessionsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    email = params[:email].to_s.downcase.strip
    password = params[:password].to_s
    user = User.find_by(email: email)

    if user.nil?
      flash.now[:alert] = "No account found for that email."
      return render :new, status: :unprocessable_entity
    end

    # Password check logic:
    # - If the user has a password set, REQUIRE it to match
    # - If the user has no password yet (seeded users from the email-only era),
    #   let them sign in with just email — but force them to set a password on
    #   their next request via the /set-password flow
    if user.password_set?
      unless user.authenticate(password)
        flash.now[:alert] = "Wrong password."
        return render :new, status: :unprocessable_entity
      end
    end

    session[:user_id] = user.id

    if session[:pending_join_code].present?
      team = TennisTeam.find_by(join_code: session.delete(:pending_join_code))
      if team && !team.team_memberships.exists?(user: user)
        TeamMembership.create!(user: user, tennis_team: team, role: "player")
      end
    end

    if user.password_set?
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      # New user / legacy user with no password — send them to set one
      redirect_to set_password_path, notice: "Welcome! Please set a password for your account."
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "You've been signed out."
  end
end
