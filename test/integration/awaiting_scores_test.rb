require "test_helper"

class AwaitingScoresTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Await Cap", email: "await-cap@example.com", password: "tennis-123")
    @player = User.create!(name: "Await Player", email: "await-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Await Aces", league_category: "USTA")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @team.matches.create!(opponent: "No Score Yet", match_date: 3.days.ago)
    @team.matches.create!(opponent: "Scored Rival", match_date: 10.days.ago, result: "win", score_summary: "2-1")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "a past match without a score stays listed, flagged, with the upload button for captains" do
    sign_in(@captain)
    get team_path(@team)
    assert_select ".cr-awaiting-alert", text: /1 past match still needs scores/
    assert_select ".cr-awaiting-row", text: /No Score Yet/
    assert_select "a.cr-awaiting-alert-btn[href='#{usta_upload_team_path(@team)}']"
    assert_match "Scored Rival", response.body
  end

  test "players see the flag but no upload button" do
    sign_in(@player)
    get team_path(@team)
    assert_select ".cr-awaiting-row .cr-awaiting-badge", text: "Scores needed"
    assert_select "a.cr-awaiting-alert-btn", count: 0
  end
end
