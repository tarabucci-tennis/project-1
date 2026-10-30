class RegistrationsController < ApplicationController
  # Bot protection, invisible to real people:
  #  - at most 5 sign-ups per hour from one internet address,
  #  - a hidden "leave this empty" box that only bots fill in,
  #  - the form must have been open a few seconds (bots submit instantly),
  #  - a name can't contain links, long numbers or symbols like $ (spam
  #    sign-ups put an ad where the name goes).
  rate_limit to: 5, within: 1.hour, only: :create,
             with: -> { redirect_to signup_path, alert: "Too many sign-ups from here. Please try again in an hour." }

  MIN_FORM_SECONDS = 3
  SPAMMY_NAME = %r{https?:|www\.|\.(com|net|org|ru|info|xyz|top|biz|io)\b|[$<>@/\\]|\d{2,}}i

  def new
    redirect_to root_path if current_user
  end

  def create
    if bot_signup?
      flash.now[:alert] = "Sorry, that didn't go through. Please press Sign Up again."
      return render :new, status: :unprocessable_entity
    end

    email                 = params[:email].to_s.downcase.strip
    name                  = params[:name].to_s.strip
    password              = params[:password].to_s
    password_confirmation = params[:password_confirmation].to_s

    if email.blank? || name.blank?
      flash.now[:alert] = "Please fill in your name and email."
      return render :new, status: :unprocessable_entity
    end

    if name.length > 60 || name.match?(SPAMMY_NAME)
      flash.now[:alert] = "Please enter just your name (no links, numbers or symbols)."
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
      return redirect_to login_path(email: email),
                         notice: "You already have an account — just sign in."
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
      user.record_sign_in!

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

  private

  # The hidden box was filled in, or the form came back without its signed
  # start time, too fast, or more than a day later.
  def bot_signup?
    return true if params[:cr_contact_me].present?
    started = Rails.application.message_verifier(:signup_form).verified(params[:form_started].to_s)
    started.nil? || Time.current.to_i - started.to_i < MIN_FORM_SECONDS
  rescue ArgumentError
    true
  end
end
