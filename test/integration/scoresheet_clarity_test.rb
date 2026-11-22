require "test_helper"

# Tara's list #102/#114/#122 (Nov 22 2026): the W/L badge is our team's result,
# so our pair goes on top, each pair is labelled with its team, and the line
# total + league rule explain split-set results.
class ScoresheetClarityTest < ActionDispatch::IntegrationTest
  setup do
    @tara = User.create!(name: "SC Tara", email: "sc@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @tara, name: "SC Legacy", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @tara, tennis_team: @team, role: "captain")
    @m = @team.matches.create!(opponent: "Penn Oaks 1", match_date: 2.days.ago, result: "loss", score_summary: "2-4")
    l1 = @m.match_lines.create!(line_type: "doubles", position: 1, result: "loss", set1_score: "0-6", set2_score: "3-6", set3_score: "1-4",
                                opponents: "Ali Hissey / Ana Ochoa")
    l1.match_line_players.create!(user: @tara)
    l6 = @m.match_lines.create!(line_type: "doubles", position: 6, result: "win", set1_score: "6-1", set2_score: "4-6")
    l6.match_line_players.create!(user: @tara)
    post session_path, params: { email: @tara.email, password: "tennis-123" }
  end

  test "our pair first, team labels, set headers, game totals and the league rule" do
    get team_match_path(@team, @m)
    assert_select ".cr-sheet-rule", text: /Del-Tri: each line goes to the pair with the most total games/
    assert_select ".cr-sheet-line", 2
    assert_select ".cr-sheet-line:first-of-type .cr-sheet-pair-ours + .cr-sheet-pair-theirs"
    assert_select ".cr-sheet-pair-ours .cr-sheet-team", text: "SC Legacy"
    assert_select ".cr-sheet-pair-theirs .cr-sheet-team", text: "Penn Oaks 1"
    assert_select ".cr-sheet-sethead .cr-sheet-set", text: "Set 3"
    assert_select ".cr-sheet-total", text: "4–16 games"
    assert_select ".cr-sheet-total", text: "10–7 games"
  end

  test "USTA and Cup count sets" do
    assert_equal :sets, TennisTeam.new(league_category: "USTA").line_rule
    assert_equal :sets, TennisTeam.new(league_category: "Inter-Club").line_rule
    assert_equal :games, @team.line_rule
  end
end
