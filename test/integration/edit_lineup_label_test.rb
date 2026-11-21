require "test_helper"

class EditLineupLabelTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Label Captain", email: "label-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Label Club", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @match = @team.matches.create!(match_date: 2.days.from_now, opponent: "Frog Hollow Orange")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
  end

  test "button says Set Lineup until someone is on a line, then Edit Lineup" do
    get team_match_path(@team, @match)
    assert_select "a.cr-set-lineup-btn", text: "Set Lineup"

    lineup = @match.create_lineup!(published: true, published_at: Time.current)
    lineup.lineup_slots.create!(line_type: "doubles", position: 1, user: @captain)
    get team_match_path(@team, @match)
    assert_select "a.cr-set-lineup-btn", text: "Edit Lineup"
  end
end
