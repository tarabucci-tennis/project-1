require "test_helper"

# Step A (Nov 17 2026): one obvious "Enter scores" button for captains.
class EnterScoresButtonTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Btn Cap", email: "btn-cap@example.com", password: "tennis-123")
    @player = User.create!(name: "Btn Player", email: "btn-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Btn Aces", league_category: "USTA")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @played = @team.matches.create!(opponent: "Rivals", match_date: 2.days.ago)
    @future = @team.matches.create!(opponent: "Later", match_date: 5.days.from_now)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "the match page has Enter scores for captains once the match day arrives" do
    sign_in(@cap)
    get team_match_path(@team, @played)
    assert_select "a.cr-match-scores-btn[href=?]", edit_results_team_match_path(@team, @played), text: "Enter scores"
    # USTA: typing and uploading are both offered.
    assert_select ".cr-upload-card-actions a", text: "Upload Send To Excel file"

    get team_match_path(@team, @future)
    assert_select "a.cr-match-scores-btn", count: 0
  end

  test "opening the form (which makes blank lines) doesn't turn the label into Edit" do
    sign_in(@cap)
    get edit_results_team_match_path(@team, @played)
    assert @played.reload.match_lines.any?
    get team_match_path(@team, @played)
    assert_select "a.cr-match-scores-btn", text: "Enter scores"

    @played.match_lines.first.update!(set1_score: "6-2", result: "win")
    get team_match_path(@team, @played)
    assert_select "a.cr-match-scores-btn", text: "Edit scores"
  end

  test "the Scores needed row goes straight to the form, for USTA too" do
    sign_in(@cap)
    get team_path(@team)
    assert_select "a.cr-awaiting-badge-link[href=?]", edit_results_team_match_path(@team, @played), text: "Enter scores"
  end

  test "players don't get the button" do
    sign_in(@player)
    get team_match_path(@team, @played)
    assert_select "a.cr-match-scores-btn", count: 0
  end
end
