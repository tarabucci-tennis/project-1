class SessionsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user&.password_digest.present?
      if user.authenticate(params[:password])
        session[:user_id] = user.id
        if session[:join_team_id]
          team = Team.find_by(id: session.delete(:join_team_id))
          if team && !team.team_players.exists?(user: user)
            team.team_players.create!(user: user, player_name: user.name, role: "player")
          end
          redirect_to team_path(team), notice: "Welcome back! You joined #{team.name}."
        else
          redirect_to root_path, notice: "Welcome back, #{user.name}!"
        end
      else
        flash.now[:alert] = "Incorrect password."
        render :new, status: :unprocessable_entity
      end
    elsif user
      # Legacy email-only login (no password set yet)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "No account found for that email."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been signed out."
  end
end
