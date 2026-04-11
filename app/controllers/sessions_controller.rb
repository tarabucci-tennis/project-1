class SessionsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user && authenticated?(user, params[:password].to_s)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "You've been signed out."
  end

  private

  def authenticated?(user, password)
    if user.password_digest.present?
      user.authenticate(password)
    else
      # Allow passwordless login for users who haven't set a password yet
      true
    end
  end
end
