require "test_helper"

# QA list #7 and #8: Best Partner needs 3+ matches together; no singles
# played reads "—" / "No singles yet", never "0% · 0 of 0".
class ProfileStatsRulesTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Stat Me", email: "stat-me@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @me, name: "Stat Club", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "player")
    @steady = User.create!(name: "Steady Partner")
    @once = User.create!(name: "Once Partner")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  def line(partner, result, days)
    m = @team.matches.create!(match_date: days.days.ago, opponent: "Club #{days}", result: result)
    l = m.match_lines.create!(line_type: "doubles", position: 1, set1_score: "6-3", result: result)
    l.match_line_players.create!(user: @me)
    l.match_line_players.create!(user: partner)
  end

  test "a 1-0 partner never beats a 3-match partner; no singles shows a dash" do
    line(@once, "win", 1)
    line(@steady, "win", 2)
    line(@steady, "win", 3)
    line(@steady, "loss", 4)
    get player_path(@me)
    assert_select ".cr-lineup-fact", text: /Best Partner\s*Steady Partner/
    assert_select ".cr-playing-stat-card", text: /—\s*Singles Win %\s*No singles yet/
  end

  test "with no 3-match partner, Best Partner explains instead of naming a 1-0 pairing" do
    line(@once, "win", 1)
    get player_path(@me)
    assert_select ".cr-lineup-fact", text: /Best Partner\s*Needs 3\+ matches together/
  end
end
