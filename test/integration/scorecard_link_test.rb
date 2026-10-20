require "test_helper"

class ScorecardLinkTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Card Cap", email: "card-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Card Team", league_category: "USTA")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @match = @team.matches.create!(opponent: "Rivals", match_date: 3.days.ago, result: "win", score_summary: "2-1")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
  end

  test "a captain saves the scorecard link and it shows in the result pop-up" do
    url = "https://tennislink.usta.com/Leagues/Main/StatsAndStandings.aspx?t=3&par1=X"
    patch team_match_path(@team, @match), params: { match: { scorecard_url: " #{url} " } }
    assert_equal url, @match.reload.scorecard_url

    get team_path(@team)
    assert_select "a[href=?]", url, text: /Official scorecard/
    assert_select "button[data-share-url=?]", url
  end

  test "a non-web link is refused" do
    patch team_match_path(@team, @match), params: { match: { scorecard_url: "javascript:alert(1)" } }
    assert_response :unprocessable_entity
    assert_nil @match.reload.scorecard_url
  end
end
