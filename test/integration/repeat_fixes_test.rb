require "test_helper"

# Tara's live-site list, items that kept coming back (Nov 22 2026):
# #25/#93 no lineup actions on finished matches, #17/#37 T column,
# #38/#39 Player Stats counts ties, #19/#75 team colors line.
class RepeatFixesTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "RF Cap", email: "rf-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "RF Legacy", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    @done = @team.matches.create!(opponent: "Penn Oaks 1", match_date: 2.days.ago, result: "loss", score_summary: "2-4")
    @tie = @team.matches.create!(opponent: "Radnor", match_date: 9.days.ago, result: "tie", score_summary: "3-3")
    @next = @team.matches.create!(opponent: "Brandywine 1", match_date: 5.days.from_now)
    post session_path, params: { email: @cap.email, password: "tennis-123" }
  end

  test "a finished match offers no Set Lineup or Ask who can play; an upcoming one still does" do
    get team_match_path(@team, @done)
    assert_select "a", text: "Set Lineup", count: 0
    assert_no_match(/Ask who can play/, response.body)
    get team_match_path(@team, @next)
    assert_select "a", text: "Set Lineup"
  end

  test "team page: no Set lineup link for the finished match, still there for the upcoming one" do
    get team_path(@team)
    assert_select "a[href='#{edit_team_match_lineup_path(@team, @done)}']", count: 0
    assert_select "a[href='#{edit_team_match_lineup_path(@team, @next)}']"
  end

  test "a match finished today shows Edit scores, not Set lineup, in the schedule" do
    travel_to Time.utc(2026, 11, 20, 23, 0) do # 6 PM Eastern
      today = @team.matches.create!(opponent: "Today Opp", match_date: Time.utc(2026, 11, 20, 10, 0), match_time: "10:00 AM",
                                    result: "loss", score_summary: "2-4")
      get team_path(@team)
      assert_select "a[href='#{edit_team_match_lineup_path(@team, today)}']", count: 0
    end
  end

  test "standings show a T column" do
    get teams_path(tab: "standings")
    assert_select ".cr-home-st th", text: "T"
    assert_select ".cr-home-st .cr-st-t", text: "1"
  end

  test "Player Stats record keeps the tie" do
    get team_path(@team)
    assert_select ".cr-chart-summary-value", text: /0–1–1/
    assert_select ".cr-chart-summary-detail", text: /25% win rate\s+· 2 matches/
    assert_select ".cr-chart-recent-badge", text: "T"
  end

  test "team colors line always shows" do
    get team_path(@team)
    assert_select ".cr-team-colors-text", text: /Team colors:\s+not set/
  end
end
