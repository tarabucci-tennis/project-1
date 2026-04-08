class TeamsController < ApplicationController
  before_action :require_login
  before_action :set_team, only: [ :show, :edit, :update, :availability_grid ]
  before_action :require_captain, only: [ :edit, :update, :availability_grid ]

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

  def availability_grid
    @matches = @team.scheduled_matches.upcoming.includes(:player_availabilities)
    @players = @team.team_players.ordered.includes(:player_availabilities)
    @avail_map = {}
    @players.each do |player|
      @avail_map[player.id] = {}
      player.player_availabilities.each do |a|
        @avail_map[player.id][a.scheduled_match_id] = a
      end
    end
  end

  def upload_schedule
    @team = current_user.captained_teams.build(
      name: params[:name],
      league: params[:league],
      rating: params[:rating],
      home_court: params[:home_court],
      gender: "F",
      section: "Middle States"
    )

    if @team.save
      @team.team_players.create!(user: current_user, player_name: current_user.name, role: "captain")

      if params[:schedule_file].present?
        parse_schedule_file(params[:schedule_file], @team)
      end

      redirect_to team_path(@team), notice: "#{@team.name} created with #{@team.scheduled_matches.count} matches imported!"
    else
      redirect_to new_team_path, alert: "Could not create team: #{@team.errors.full_messages.join(', ')}"
    end
  end

  def invite_captain
    # Send invite email to captain
    if params[:captain_email].present?
      CaptainMailer.captain_invite(
        params[:captain_email],
        params[:captain_name],
        params[:team_name],
        params[:message],
        current_user
      ).deliver_later rescue nil

      redirect_to teams_path, notice: "Invitation sent to #{params[:captain_name]} at #{params[:captain_email]}!"
    else
      redirect_to new_team_path, alert: "Please enter your captain's email."
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

  def parse_schedule_file(file, team)
    require "csv"
    content = file.read

    # Try to parse as CSV
    rows = CSV.parse(content, headers: true, liberal_parsing: true) rescue nil
    return unless rows

    rows.each do |row|
      # Try common column names from USTA TennisLink exports
      date_val = row["Date"] || row["Match Date"] || row["date"] || row["Start Date"] || row.fields[0]
      opp_val = row["Opponent"] || row["opponent"] || row["Opposing Team"] || row["Away Team"] || row.fields[1]
      ha_val = row["Home/Away"] || row["H/A"] || row["Location Type"] || row.fields[2]
      loc_val = row["Location"] || row["Venue"] || row["location"] || row["Facility"] || row.fields[3]

      next unless date_val.present? && opp_val.present?

      begin
        match_date = Date.parse(date_val.to_s.strip)
      rescue
        next
      end

      home_away = if ha_val.to_s.strip.downcase.start_with?("h")
        "home"
      else
        "away"
      end

      team.scheduled_matches.find_or_create_by!(
        match_date: match_date,
        opponent_team: opp_val.to_s.strip
      ) do |m|
        m.home_away = home_away
        m.location = loc_val.to_s.strip
      end
    end
  rescue => e
    Rails.logger.error "Schedule import error: #{e.message}"
  end
end
