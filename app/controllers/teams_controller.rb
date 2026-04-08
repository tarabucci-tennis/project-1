class TeamsController < ApplicationController
  before_action :require_login
  before_action :set_team, only: [ :show, :edit, :update ]
  before_action :require_captain, only: [ :edit, :update ]

  def index
    @my_teams = current_user.team_players.includes(team: :captain).map(&:team).uniq
    @leagues = @my_teams.group_by(&:league)
  end

  def show
    @matches = @team.scheduled_matches.chronological.includes(:player_availabilities, :lineup_slots, :match_scores)
    @players = @team.team_players.ordered
    @is_captain = current_user.captain_of?(@team)
    @my_player = @team.team_players.find_by(user: current_user)
    @my_availabilities = {}
    if @my_player
      @my_player.player_availabilities.where(scheduled_match: @matches).each do |a|
        @my_availabilities[a.scheduled_match_id] = a
      end
    end
  end

  def new
    @team = Team.new
  end

  def create
    @team = current_user.captained_teams.build(team_params)
    if @team.save
      @team.team_players.create!(
        user: current_user,
        player_name: current_user.name,
        role: "captain"
      )
      redirect_to team_path(@team), notice: "#{@team.name} created! Share your join link with your team."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Handle "add player" from the edit page
    if params[:add_player].present? && params[:add_player_name].present?
      user = nil
      if params[:add_player_email].present?
        user = User.find_or_create_by(email: params[:add_player_email].downcase.strip) do |u|
          u.name = params[:add_player_name]
        end
      end
      @team.team_players.find_or_create_by!(player_name: params[:add_player_name]) do |tp|
        tp.user = user
        tp.role = "player"
      end
      redirect_to edit_team_path(@team), notice: "#{params[:add_player_name]} added!"
      return
    end

    if @team.update(team_params)
      redirect_to team_path(@team), notice: "Team updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end

  def set_team
    @team = Team.find(params[:id])
  end

  def require_captain
    unless current_user.captain_of?(@team) || current_user.super_admin?
      redirect_to team_path(@team), alert: "Only the captain can do that."
    end
  end

  def team_params
    params.require(:team).permit(:name, :league, :team_type, :section, :gender, :rating, :home_court, :usta_team_number)
  end
end
