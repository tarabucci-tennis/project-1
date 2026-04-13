class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    email                 = params[:email].to_s.downcase.strip
    name                  = params[:name].to_s.strip
    password              = params[:password].to_s
    password_confirmation = params[:password_confirmation].to_s

    if email.blank? || name.blank?
      flash.now[:alert] = "Please fill in your name and email."
      return render :new, status: :unprocessable_entity
    end

    if password.length < 6
      flash.now[:alert] = "Password must be at least 6 characters."
      return render :new, status: :unprocessable_entity
    end

    if password != password_confirmation
      flash.now[:alert] = "Passwords don't match. Try again."
      return render :new, status: :unprocessable_entity
    end

    existing = User.find_by(email: email)
    if existing
      flash.now[:alert] = "That email is already registered. Try signing in instead."
      return render :new, status: :unprocessable_entity
    end

    # If the visitor came in through a team join link, see if the
    # captain already seeded them as a placeholder on that team
    # (same name, no password, maybe no email). If so, claim that
    # placeholder instead of creating a duplicate user — this
    # preserves their lineup assignments, match history, etc.
    pending_team = nil
    if session[:pending_join_code].present?
      pending_team = TennisTeam.find_by(join_code: session[:pending_join_code])
    end

    user = nil
    if pending_team
      placeholder = pending_team.members
                                .where(password_digest: nil)
                                .where("LOWER(name) = ?", name.downcase)
                                .first
      # Only reuse a placeholder if its email slot is empty or already
      # matches what the signup form says (we don't want to overwrite
      # an email a captain may have typed in).
      if placeholder && (placeholder.email.blank? || placeholder.email.to_s.downcase == email)
        user = placeholder
        user.email                 = email
        user.password              = password
        user.password_confirmation = password_confirmation
      end
    end

    # No placeholder → normal fresh account creation.
    user ||= User.new(
      name:                  name,
      email:                 email,
      admin:                 false,
      password:              password,
      password_confirmation: password_confirmation
    )

    if user.save
      session[:user_id] = user.id

      if session[:pending_join_code].present?
        team = TennisTeam.find_by(join_code: session.delete(:pending_join_code))
        if team && !team.team_memberships.exists?(user: user)
          TeamMembership.create!(user: user, tennis_team: team, role: "player")
        end
        if team
          redirect_to team_path(team),
                      notice: "Welcome to Court Report! You're all set on #{team.name}."
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
