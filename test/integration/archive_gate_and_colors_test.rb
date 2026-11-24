require "test_helper"

# QA qa-169: no Archive Season before a match is played.
# QA qa-170: the hero colour legend shows swatches + colour names only.
class ArchiveGateAndColorsTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Gate Captain", email: "gate-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @me, name: "Gate Club", league_category: "USTA", league_name: "USTA Adult 18+",
                               team_colors: "Gold: #C9A227 1.0, Navy")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "captain")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "Archive Season is hidden until a match has been played" do
    @team.matches.create!(opponent: "Later", match_date: 10.days.from_now)
    get team_path(@team)
    assert_select "input[value='Archive Season']", count: 0

    @team.matches.create!(opponent: "Done", match_date: 10.days.ago, result: "win")
    get team_path(@team)
    assert_select "input[value='Archive Season']", count: 1
  end

  test "colour legend shows names, never hex codes or numbers" do
    get team_path(@team)
    legend = css_select(".cr-team-colors").first.text
    assert_includes legend, "Gold"
    assert_includes legend, "Navy"
    assert_no_match(/#\h{3,8}|1\.0/, legend)
    assert_select ".cr-team-colors .cr-color-item", 2
  end
end
