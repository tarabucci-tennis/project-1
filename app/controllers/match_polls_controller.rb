# The "Can you play?" link a captain texts for one match (/a/:token). Anyone
# with the link sees the team's names and taps Yes or No next to their own,
# no account needed. Answers are saved as the player's availability, so the
# captain sees them in Court Report too. The phone remembers who answered
# so it can show "You" next time.
class MatchPollsController < ApplicationController
  ME_COOKIE = :match_poll_me

  before_action :load_match

  def show
    @team = @match.tennis_team
    @players = roster
    @answers = @match.availabilities.where(user_id: @players.map(&:id)).index_by(&:user_id)
    @me_id = cookies.signed[ME_COOKIE].to_i
  end

  def answer
    player = roster.find { |u| u.id == params[:user_id].to_i }
    status = params[:status].to_s
    unless player && %w[in out].include?(status)
      return redirect_to match_poll_path(@match.availability_token), alert: "Pick your name, then Yes or No."
    end

    availability = Availability.find_or_initialize_by(user: player, match: @match)
    availability.status = status
    notify_captains(player, availability) if availability.save && availability.status_previously_changed?
    cookies.permanent.signed[ME_COOKIE] = player.id

    redirect_to match_poll_path(@match.availability_token, anchor: "p#{player.id}"),
                notice: status == "in" ? "Thanks, #{player.name.split.first}! You're down as able to play." : "Thanks, #{player.name.split.first}. You're down as can't play."
  end

  private

  def load_match
    @match = Match.includes(:tennis_team).find_by(availability_token: params[:token].to_s)
    render plain: "This link isn't valid anymore. Ask your captain for a new one.", status: :not_found unless @match
  end

  # Everyone on the team's current roster, A to Z.
  def roster
    @roster ||= User.joins(:team_memberships)
                    .merge(TeamMembership.active)
                    .where(team_memberships: { tennis_team_id: @match.tennis_team_id })
                    .distinct.to_a.sort_by { |u| u.name.to_s.downcase }
  end

  def notify_captains(player, availability)
    team = @match.tennis_team
    team.team_memberships.captains.each do |membership|
      next if membership.notification_preference == "off"
      next if membership.user_id == player.id

      Notification.create!(
        user: membership.user, tennis_team: team, match: @match, actor: player, kind: "availability_update",
        body: "#{player.name} marked #{availability.status == 'in' ? 'In' : 'Out'} for #{@match.match_date.strftime('%-m/%-d')}"
      )
    end
  rescue => e
    Rails.logger.warn("Notification error: #{e.message}")
  end
end
