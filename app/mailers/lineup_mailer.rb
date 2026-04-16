class LineupMailer < ApplicationMailer
  default from: "Court Report <courtreport.app@gmail.com>"

  def lineup_posted(lineup_slot)
    @slot = lineup_slot
    @lineup = lineup_slot.lineup
    @match = @lineup.match
    @team = @match.tennis_team
    @player = lineup_slot.user
    @line_label = lineup_slot.line_label
    @confirm_url = confirm_team_match_lineup_url(
      @team, @match,
      status: "confirmed",
      host: "yourcourtreport.com",
      protocol: "https"
    )
    @decline_url = confirm_team_match_lineup_url(
      @team, @match,
      status: "declined",
      host: "yourcourtreport.com",
      protocol: "https"
    )

    mail(
      to: @player.email,
      subject: "You're in the lineup! #{@team.name} vs. #{@match.opponent}"
    )
  end
end
