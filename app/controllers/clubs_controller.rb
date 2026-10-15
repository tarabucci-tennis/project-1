# Add / edit / remove the clubs (and addresses) for Bux-Mont and Del-Tri.
# Reached from the Standings tab of a team in that league; `team_id` is
# carried along so Save brings you back there.
class ClubsController < ApplicationController
  before_action :require_login
  before_action :load_club, only: [ :edit, :update, :destroy ]
  before_action :require_editor

  def new
    @club = Club.new(league: league)
  end

  def create
    @club = Club.new(club_params.merge(league: league))
    if @club.save
      redirect_to back_path, notice: "#{@club.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @club.update(club_params)
      redirect_to back_path, notice: "#{@club.name} saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @club.destroy
    redirect_to back_path, notice: "#{@club.name} removed."
  end

  helper_method :back_path

  private

  def load_club
    @club = Club.find_by(id: params[:id])
    redirect_to(teams_path, alert: "That club isn't on the list anymore.") unless @club
  end

  def league
    @club&.league || params[:league].to_s
  end

  def require_editor
    unless Club::LEAGUES.include?(league) && Club.editable_by?(current_user, league)
      redirect_to back_path, alert: "Only admins and captains in that league can change club addresses."
    end
  end

  def club_params
    params.require(:club).permit(:name, :address, :aliases)
  end

  def back_path
    team = TennisTeam.find_by(id: params[:team_id])
    team ? team_path(team, tab: "standings", anchor: "clubs") : teams_path
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
