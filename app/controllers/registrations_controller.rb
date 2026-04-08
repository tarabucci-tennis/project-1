class RegistrationsController < ApplicationController
  def new
    @user = User.new
    if params[:token]
      invited = User.find_by(invite_token: params[:token])
      @user = invited if invited
      @team = invited&.team_players&.last&.team
    end
  end

  def create
    @user = User.find_by(invite_token: params[:invite_token]) if params[:invite_token].present?
    @user ||= User.new

    @user.assign_attributes(registration_params)
    @user.invite_token = nil if @user.invite_token.present?

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to Court Report, #{@user.name}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def join
    team = Team.find_by!(join_code: params[:code])
    if current_user
      unless team.team_players.exists?(user: current_user)
        team.team_players.create!(
          user: current_user,
          player_name: current_user.name,
          role: "player"
        )
      end
      redirect_to team_path(team), notice: "You joined #{team.name}!"
    else
      session[:join_team_id] = team.id
      redirect_to signup_path, notice: "Sign up to join #{team.name}!"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid team link."
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
  end
end
