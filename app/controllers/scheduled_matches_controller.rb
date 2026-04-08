class ScheduledMatchesController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :set_match, only: [ :show, :edit, :update, :update_lineup, :update_availability, :confirm_lineup_spot ]
  before_action :require_captain, only: [ :new, :create, :edit, :update, :update_lineup ]

  def show
    @players = @team.team_players.ordered
    @availabilities = @match.player_availabilities.includes(:team_player).index_by(&:team_player_id)
    @lineup = @match.lineup_slots.includes(:team_player).group_by(&:position)
    @scores = @match.match_scores.includes(:player1, :player2).index_by(&:position)
    @is_captain = current_user.captain_of?(@team)
  end

  def new
    @match = @team.scheduled_matches.build
  end

  def create
    @match = @team.scheduled_matches.build(match_params)
    if @match.save
      # Create pending availability for all roster members
      @team.team_players.each do |player|
        @match.player_availabilities.create(team_player: player, status: "pending")
      end
      redirect_to team_path(@team), notice: "Match added!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @match.update(match_params)
      redirect_to team_scheduled_match_path(@team, @match), notice: "Match updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_lineup
    @match.lineup_slots.destroy_all
    if params[:lineup].present?
      params[:lineup].each do |position, player_ids|
        Array(player_ids).reject(&:blank?).each do |player_id|
          @match.lineup_slots.create!(team_player_id: player_id, position: position)
        end
      end
    end
    redirect_to team_scheduled_match_path(@team, @match), notice: "Lineup updated!"
  end

  def confirm_lineup_spot
    my_player = @team.team_players.find_by(user: current_user)
    slot = @match.lineup_slots.find_by(team_player: my_player)
    if slot
      message = params[:confirmation_message].presence
      slot.confirm!(message)
      redirect_back fallback_location: team_scheduled_match_path(@team, @match), notice: "Lineup confirmed! #{message || '✅'}"
    else
      redirect_back fallback_location: team_scheduled_match_path(@team, @match), alert: "You're not in the lineup for this match."
    end
  end

  def update_availability
    player = @team.team_players.find(params[:team_player_id])
    avail = @match.player_availabilities.find_or_initialize_by(team_player: player)
    avail.status = params[:status]
    avail.message = params[:message] if params[:status] == "custom"
    avail.save!
    notify_captain(player, avail)
    redirect_back fallback_location: team_scheduled_match_path(@team, @match), notice: "#{avail.confirmed? ? '✅ Available' : '❌ Unavailable'} for #{@match.opponent_team}"
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end

  def set_team
    @team = Team.find(params[:team_id])
  end

  def set_match
    @match = @team.scheduled_matches.find(params[:id])
  end

  def require_captain
    unless current_user.captain_of?(@team) || current_user.super_admin?
      redirect_to team_path(@team), alert: "Only the captain can do that."
    end
  end

  def match_params
    params.require(:scheduled_match).permit(:match_date, :match_time, :opponent_team, :home_away, :location)
  end

  def notify_captain(player, avail)
    captain = @team.captain
    return if captain.notifications_off?
    return if captain.id == current_user&.id

    notification = captain.captain_notifications.create!(
      scheduled_match: @match,
      team_player: player,
      event_type: avail.status == "custom" ? "custom" : avail.status,
      message: avail.message
    )

    if captain.notify_every_update? && captain.email.present?
      CaptainMailer.availability_update(captain, notification).deliver_later
    end
  end
end
