class CaptainMailer < ApplicationMailer
  def captain_invite(email, captain_name, team_name, message, inviter)
    @captain_name = captain_name
    @team_name = team_name
    @message = message
    @inviter = inviter

    mail(
      to: email,
      subject: "#{inviter.name} invited you to set up #{team_name} on Court Report"
    )
  end

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
