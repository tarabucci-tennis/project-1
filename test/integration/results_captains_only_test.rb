require "test_helper"

class ResultsCaptainsOnlyTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(name: "Res Owner", email: "res-owner@example.com", password: "tennis-123")
    @captain = User.create!(name: "Res Captain", email: "res-captain@example.com", password: "tennis-123")
    @player = User.create!(name: "Res Player", email: "res-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @owner, name: "Results Team", league_category: "USTA")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @match = @team.matches.create!(opponent: "Rivals", match_date: 2.days.from_now)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "a player can't open or save Enter Results, or upload USTA files" do
    sign_in(@player)
    get edit_results_team_match_path(@team, @match)
    assert_redirected_to team_path(@team)

    patch results_team_match_path(@team, @match), params: { match_result: "win" }
    assert_nil @match.reload.result

    get usta_upload_team_path(@team)
    assert_redirected_to team_path(@team)

    get team_path(@team)
    assert_no_match "Enter them now", response.body
    assert_select "a[href='#{edit_results_team_match_path(@team, @match)}']", count: 0
  end

  test "the captain can enter results" do
    sign_in(@captain)
    get edit_results_team_match_path(@team, @match)
    assert_response :success
    get team_path(@team)
    assert_select "a[href='#{edit_results_team_match_path(@team, @match)}']"
  end
end
