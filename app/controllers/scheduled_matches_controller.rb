class ScheduledMatchesController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :set_match, only: [ :show, :update_lineup, :update_availability ]

  def show
    @players = @team.team_players.ordered
    @availabilities = @match.player_availabilities.includes(:team_player).index_by(&:team_player_id)
    @lineup = @match.lineup_slots.includes(:team_player).group_by(&:position)
  end

  def update_lineup
    # Clear existing lineup and rebuild
    @match.lineup_slots.destroy_all

    if params[:lineup].present?
      params[:lineup].each do |position, player_ids|
        Array(player_ids).reject(&:blank?).each do |player_id|
          @match.lineup_slots.create!(
            team_player_id: player_id,
            position: position
          )
        end
      end
    end

    redirect_to team_scheduled_match_path(@team, @match), notice: "Lineup updated!"
  end

  def update_availability
    player = @team.team_players.find(params[:team_player_id])
    avail = @match.player_availabilities.find_or_initialize_by(team_player: player)

    avail.status = params[:status]
    avail.message = params[:message] if params[:status] == "custom"
    avail.save!

    notify_captain(player, avail)

    redirect_to team_scheduled_match_path(@team, @match), notice: "Availability updated!"
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

  def notify_captain(player, avail)
    captain = @team.captain
    return if captain.notifications_off?
    return if captain.id == current_user&.id # don't notify yourself

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
