class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  def create
    email = params[:email].to_s.downcase.strip
    name  = params[:name].to_s.strip

    if email.blank? || name.blank?
      flash.now[:alert] = "Please fill in both your name and email."
      return render :new, status: :unprocessable_entity
    end

    existing = User.find_by(email: email)
    if existing
      flash.now[:alert] = "That email is already registered. Try signing in instead."
      return render :new, status: :unprocessable_entity
    end

    user = User.new(name: name, email: email, admin: false)
    if user.save
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome to Court Report, #{user.name.split.first}!"
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
end
