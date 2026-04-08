class CaptainMailer < ApplicationMailer
  def availability_update(captain, notification)
    @captain = captain
    @notification = notification
    @player = notification.team_player
    @match = notification.scheduled_match
    @team = @match.team

    mail(
      to: captain.email,
      subject: "#{@player.display_name} #{notification.event_label} — #{@team.name} vs. #{@match.opponent_team}"
    )
  end
end
