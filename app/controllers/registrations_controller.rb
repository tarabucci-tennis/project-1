class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    email = params[:email].to_s.downcase.strip
    name  = params[:name].to_s.strip

    if email.blank? || name.blank? || params[:password].blank?
      flash.now[:alert] = "Please fill in all fields."
      return render :new, status: :unprocessable_entity
    end

    existing = User.find_by(email: email)
    if existing
      flash.now[:alert] = "That email is already registered. Try signing in instead."
      return render :new, status: :unprocessable_entity
    end

    user = User.new(name: name, email: email, admin: false, password: params[:password], password_confirmation: params[:password_confirmation])
    if user.save
      session[:user_id] = user.id

      if session[:pending_join_code].present?
        team = TennisTeam.find_by(join_code: session.delete(:pending_join_code))
        if team && !team.team_memberships.exists?(user: user)
          TeamMembership.create!(user: user, tennis_team: team, role: "player")
          redirect_to team_path(team), notice: "Welcome to Court Report! You've joined #{team.name}."
          return
        end
      end

      redirect_to root_path, notice: "Welcome to Court Report, #{user.name.split.first}!"
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
end
