class PasswordResetsController < ApplicationController
  # GET /forgot-password — show the form
  def new
  end

  # POST /forgot-password — send reset email
  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.email.present?
      token = user.generate_reset_token!
      PasswordResetMailer.reset_email(user, token).deliver_later
    end

    # Always show success (don't reveal whether email exists)
    redirect_to login_path, notice: "If that email is registered, you'll receive a password reset link."
  end

  # GET /reset-password/:token — show reset form
  def edit
    @user = User.find_by(reset_password_token: params[:token])

    unless @user&.reset_token_valid?
      redirect_to login_path, alert: "That reset link has expired. Please request a new one."
    end
  end

  # PATCH /reset-password/:token — save new password
  def update
    @user = User.find_by(reset_password_token: params[:token])

    unless @user&.reset_token_valid?
      redirect_to login_path, alert: "That reset link has expired."
      return
    end

    if params[:password].blank?
      flash.now[:alert] = "Password can't be blank."
      return render :edit, status: :unprocessable_entity
    end

    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]

    if @user.save
      @user.clear_reset_token!
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Password updated! You're signed in."
    else
      flash.now[:alert] = @user.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end
end
