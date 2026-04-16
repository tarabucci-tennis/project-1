class PasswordsController < ApplicationController
  before_action :require_login

  # GET /set-password — shown to a legacy user the first time they sign in with
  # just their email, so they can pick a password. Also usable as a "change my
  # password" screen for anyone.
  def new
  end

  # PATCH /set-password — save the new password
  def update
    password = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    if password.length < 6
      flash.now[:alert] = "Password must be at least 6 characters."
      return render :new, status: :unprocessable_entity
    end

    if password != confirmation
      flash.now[:alert] = "Passwords don't match. Try again."
      return render :new, status: :unprocessable_entity
    end

    current_user.password = password
    current_user.password_confirmation = confirmation

    if current_user.save
      redirect_to root_path, notice: "Password set. You're all set!"
    else
      flash.now[:alert] = current_user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
