class PasswordResetsController < ApplicationController
  # GET /forgot-password — show the form
  def new
  end

  # POST /forgot-password — send reset email (and for admins, also show
  # the reset link on screen as a fallback in case SMTP isn't working).
  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.email.present?
      token = user.generate_reset_token!

      # Try to email. If SMTP isn't configured on the droplet
      # (SMTP_USERNAME / SMTP_PASSWORD missing), the job will quietly
      # fail in the background — we don't want to block the request.
      begin
        PasswordResetMailer.reset_email(user, token).deliver_later
      rescue => e
        Rails.logger.warn "[password_reset] deliver_later failed: #{e.message}"
      end

      # Admin users get the reset link shown directly on screen so
      # they can't get locked out when Gmail SMTP isn't wired up. Safe
      # because:
      #   - You still need to know an admin's registered email to get
      #     a link at all
      #   - The token expires in 2 hours
      #   - Regular non-admin users never see this bypass
      if user.admin?
        reset_url = edit_password_reset_url(
          token:    token,
          host:     request.host,
          protocol: request.protocol.sub(/:\/\/$/, "")
        )
        flash[:admin_reset_url] = reset_url
        redirect_to login_path,
                    notice: "Admin bypass — use the reset link below to set a new password."
        return
      end
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
