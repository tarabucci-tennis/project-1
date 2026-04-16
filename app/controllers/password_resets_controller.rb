class PasswordResetsController < ApplicationController
  # GET /forgot-password — show the form
  def new
  end

  # POST /forgot-password — generate a reset link. SMTP is not yet
  # configured on the droplet, so emails would never arrive. For this
  # beta we show the reset link directly on the login page to every
  # user who requests one, regardless of admin status, so nobody gets
  # locked out. We also still try to email — once SMTP_USERNAME /
  # SMTP_PASSWORD are set on the server, the email path will start
  # working in parallel.
  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.email.present?
      token = user.generate_reset_token!

      # Try to email. If SMTP isn't configured, the job will quietly
      # fail in the background — we don't want to block the request.
      begin
        PasswordResetMailer.reset_email(user, token).deliver_later
      rescue => e
        Rails.logger.warn "[password_reset] deliver_later failed: #{e.message}"
      end

      reset_url = edit_password_reset_url(
        token:    token,
        host:     request.host,
        protocol: request.protocol.sub(/:\/\/$/, "")
      )
      flash[:admin_reset_url] = reset_url
      redirect_to login_path,
                  notice: "Here's your reset link — tap the gold button below to set a new password."
      return
    end

    # Email not found (and don't reveal whether it exists)
    redirect_to login_path,
                notice: "If that email is registered, you'll see a reset link below."
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
