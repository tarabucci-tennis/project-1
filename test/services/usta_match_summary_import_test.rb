require "test_helper"

# TennisLink's "Match Summary by Team" report (made-up data, same layout).
class UstaMatchSummaryImportTest < ActiveSupport::TestCase
  HTML = <<~HTML.freeze
    <table>
      <tr><td>Section</td><td>District/Area</td><td>League</td><td>Flight</td></tr>
      <tr><td>USTA/MIDDLE STATES</td><td>PHILADELPHIA</td><td>Adult Tri-Level League</td><td>Tri Level Test</td></tr>
      <tr><td>Match Summary by Team Report As of 10/16/2026 11:07 AM EST</td></tr>
      <tr><td>Match ID</td><td>Schedule Date</td><td>Schedule Time</td><td>Home Team</td><td>Team ID</td><td>Visiting Team</td><td>Team ID</td><td>Team Wins</td><td>Match Score</td><td>Match Status</td></tr>
      <tr><td>Home</td><td>Visitor</td><td>Home</td><td>Visitor</td></tr>
      <tr><td>1001</td><td>9/9/2026</td><td>4:00 AM</td><td>Test Aces</td><td>35</td><td>Rival One</td><td>*****</td><td>2</td><td>1</td><td>1</td><td>0</td><td>Confirmed by 48 hr rule Confirmed by 48 hr rule</td></tr>
      <tr><td>1002</td><td>9/16/2026</td><td>4:00 AM</td><td>The Rival Two</td><td>*****</td><td>TEST ACES</td><td>35</td><td>0</td><td>3</td><td>0</td><td>1</td><td>Reported by The Rival Two Reported by The Rival Two</td></tr>
      <tr><td>1003</td><td>9/23/2026</td><td>4:00 AM</td><td>Test Aces</td><td>35</td><td>Rival One</td><td>*****</td><td>0</td><td>0</td><td>0</td><td>0</td><td>No Team Reported No Team Reported</td></tr>
    </table>
  HTML

  setup do
    owner = User.create!(name: "Owner", email: "usta-match-summary@example.com")
    @team = owner.tennis_teams.create!(name: "Test Aces", league_category: "USTA")
    @m1 = @team.matches.create!(match_date: Time.zone.local(2026, 9, 9, 12), opponent: "Rival One")
    @parsed = UstaTeamSummaryParser.parse(HTML, team_name: @team.name)
  end

  test "reads each match from our side, home or away" do
    assert @parsed.match_summary?
    assert_equal 3, @parsed.matches.size
    away = @parsed.matches[1]
    assert_equal [ "The Rival Two", 3, 0, "win", false ], [ away.opponent, away.our_points, away.their_points, away.result, away.home ]
    assert_equal "Reported by The Rival Two", away.status
    assert_not @parsed.matches[2].played?
  end

  test "apply! updates team scores and adds missing matches, nothing else" do
    UstaTeamSummaryImport.new(@team, @parsed).apply!
    assert_equal "2-1", @m1.reload.score_summary
    assert_equal "win", @m1.result
    added = @team.matches.find_by(opponent: "The Rival Two")
    assert_equal [ "3-0", "win", "away" ], [ added.score_summary, added.result, added.home_away ]
    assert_nil @team.reload.usta_synced_at
    assert_equal 0, @team.division_teams.count
    assert_equal 3, @team.matches.count
  end

  test "a report for a different team changes nothing" do
    other = UstaTeamSummaryParser.parse(HTML, team_name: "Someone Else")
    plan = UstaTeamSummaryImport.new(@team, other).plan
    assert_match "doesn't list", plan.warnings.join
  end
end
