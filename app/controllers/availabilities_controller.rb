class AvailabilitiesController < ApplicationController
  before_action :require_login

  def update
    @match = Match.find_by(id: params[:match_id])
    unless @match
      return head :not_found
    end

    team = @match.tennis_team
    unless team.team_memberships.exists?(user: current_user)
      return head :forbidden
    end

    availability = Availability.find_or_initialize_by(user: current_user, match: @match)
    availability.status = params[:status] if params[:status].present?
    availability.message = params[:message] if params.key?(:message)

    if availability.save
      notify_captains(team, availability) if availability.status_previously_changed?

      counts = @match.availability_counts
      render json: {
        status: availability.status,
        message: availability.message,
        counts: counts
      }
    else
      render json: { error: availability.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def require_login
    head :unauthorized unless current_user
  end

  def notify_captains(team, availability)
    # Store in-app notifications for captains based on their preference
    team.team_memberships.captains.each do |membership|
      next if membership.notification_preference == "off"
      next if membership.user_id == current_user.id

      Notification.create!(
        user: membership.user,
        tennis_team: team,
        match: availability.match,
        actor: current_user,
        kind: "availability_update",
        body: "#{current_user.name} marked #{availability.status == 'in' ? 'In' : 'Out'} for #{availability.match.match_date.strftime('%-m/%-d')}"
      )
    end
  rescue => e
    # Don't fail the availability save if notifications fail
    Rails.logger.warn("Notification error: #{e.message}")
  end
end
