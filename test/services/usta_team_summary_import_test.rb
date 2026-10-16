require "test_helper"

class UstaTeamSummaryImportTest < ActiveSupport::TestCase
  # Same table layout as TennisLink's Team Summary export, with made-up data.
  HTML = <<~HTML.freeze
    <table>
      <tr><td>Section</td><td>District/Area</td><td>League</td><td>Flight/SubFlight</td></tr>
      <tr><td>USTA/MIDDLE STATES</td><td>PHILADELPHIA</td><td>Adult 40 &amp; Over</td><td>4.0 Women Test / Sub-Flight 2</td></tr>
      <tr><td>Captain</td><td>Co-Captain</td><td>Facility</td><td>League Date</td></tr>
      <tr><td>Cap Tain</td><td></td><td>Some Club</td><td>04/13/2026 - 06/30/2026 Flight Date</td></tr>
    </table>
    <table>
      <tr><th>Team Name</th><th>Matches Played</th><th>Points*</th><th>Sets Won</th><th>Sets Lost</th><th>Games Won</th><th>Games Lost</th><th>* Games Won %</th></tr>
      <tr><td>Test Aces</td><td>2</td><td>31</td><td>15</td><td>5</td><td>100</td><td>60</td><td>61.50%</td></tr>
      <tr><td>Rival One</td><td>2</td><td>15</td><td>5</td><td>15</td><td>60</td><td>100</td><td>38.50%</td></tr>
      <tr><td></td></tr>
      <tr><td>Team Matches</td></tr>
      <tr><td>Date</td><td></td><td>Opponent</td><td>Points</td><td>Date</td><td></td><td>Opponent</td><td>Points</td></tr>
      <tr><td>4/14/2026</td><td></td><td>Rival One</td><td>Confirmed by 48 hr rule 23-0 Confirmed</td><td>4/21/2026</td><td></td><td>Rival One</td><td>Confirmed by League Coordinator 8-15 Confirmed</td></tr>
      <tr><td></td><td>R-Rescheduled</td></tr>
      <tr><td>Players</td></tr>
      <tr><td>Player Name</td><td>NTRP</td><td>Player Name</td><td>NTRP</td></tr>
      <tr><td>Already Here</td><td>4</td><td>Brand New</td><td>3.5</td></tr>
      <tr><td></td></tr>
    </table>
  HTML

  setup do
    owner = User.create!(name: "Owner", email: "usta-summary-test@example.com")
    @team = owner.tennis_teams.create!(name: "Test Aces", league_category: "USTA")
    @member = User.create!(name: "Already Here", ntrp_rating: 3.5)
    TeamMembership.create!(user: @member, tennis_team: @team, role: "player")
    @m1 = @team.matches.create!(match_date: Time.zone.local(2026, 4, 14, 12), opponent: "Rival One")
    @parsed = UstaTeamSummaryParser.parse(HTML)
  end

  test "parses standings, matches and roster" do
    assert_equal [ "Test Aces", "Rival One" ], @parsed.standings.map(&:name)
    assert_equal 2, @parsed.matches.size
    assert_equal "win", @parsed.matches.first.result
    assert_equal [ 4.0, 3.5 ], @parsed.players.map(&:ntrp)
  end

  test "plan previews without saving" do
    plan = UstaTeamSummaryImport.new(@team, @parsed).plan
    assert_equal "Test Aces", plan.our_row.name
    assert_equal [ "Brand New" ], plan.players_new
    assert_equal 1, plan.matches_new.size
    assert_nil @team.reload.usta_synced_at
  end

  test "apply! stores USTA's published numbers as-is" do
    UstaTeamSummaryImport.new(@team, @parsed).apply!
    @team.reload

    assert_equal 31, @team.usta_points
    assert_equal 61.5, @team.usta_games_won_pct.to_f

    rival = @team.division_teams.find_by(name: "Rival One")
    assert_equal 15, rival.points
    assert_equal 38.5, rival.games_won_pct.to_f

    assert_equal "23-0", @m1.reload.score_summary
    assert_equal "win", @m1.result
    assert_match(/Confirmed/, @m1.usta_status)

    added = @team.matches.find_by(opponent: "Rival One", match_date: Time.zone.local(2026, 4, 21).all_day)
    assert_equal "loss", added.result

    assert_equal 4.0, @member.reload.ntrp_rating.to_f
    assert @team.team_memberships.active.joins(:user).exists?(users: { name: "Brand New" })
  end

  # Tri-Level flights rank by Team Wins and publish a different standings table.
  TEAM_WINS_HTML = <<~HTML.freeze
    <table>
      <tr><td>Match Win Criteria: Team Wins</td></tr>
      <tr><td>Team Name</td><td>Wins*</td><td>Losses</td><td>Indiv. Wins</td><td>Indiv. Losses</td><td>Sets Won</td><td>Sets Lost</td><td>Games Won</td><td>Games Lost</td><td>* Games Won %</td></tr>
      <tr><td>Test Aces</td><td>6</td><td>0</td><td>15</td><td>3</td><td>30</td><td>7</td><td>201</td><td>136</td><td>59.64%</td></tr>
      <tr><td>Rival One</td><td>4</td><td>2</td><td>9</td><td>9</td><td>19</td><td>24</td><td>162</td><td>170</td><td>48.80%</td></tr>
      <tr><td></td></tr>
      <tr><td>Team Matches</td></tr>
      <tr><td>Date</td><td></td><td>Opponent</td><td>Result</td></tr>
      <tr><td>4/14/2026</td><td></td><td>Rival One</td><td>Confirmed by 48 hr rule Won 2-1 Confirmed</td></tr>
      <tr><td>Players</td></tr>
      <tr><td>Player Name</td><td>NTRP</td></tr>
      <tr><td>Already Here</td><td>4</td></tr>
    </table>
  HTML

  test "reads Team Wins standings (Tri-Level) and saves wins as points" do
    parsed = UstaTeamSummaryParser.parse(TEAM_WINS_HTML)
    assert_equal [ 6, 6, 0 ], parsed.standings.first.to_h.values_at(:points, :wins, :losses)
    assert_equal "Confirmed by 48 hr rule", parsed.matches.first.status

    UstaTeamSummaryImport.new(@team, parsed).apply!
    assert_equal 6, @team.reload.usta_points
    rival = @team.division_teams.find_by(name: "Rival One")
    assert_equal [ 4, 2, 6, 48.8 ], [ rival.wins, rival.losses, rival.matches_played, rival.games_won_pct.to_f ]
    assert_equal "2-1", @m1.reload.score_summary
  end

  test "apply! is safe to run twice" do
    2.times { UstaTeamSummaryImport.new(@team, UstaTeamSummaryParser.parse(HTML)).apply! }
    assert_equal 2, @team.matches.count
    assert_equal 1, @team.division_teams.count
    assert_equal 2, @team.team_memberships.count
  end
end
