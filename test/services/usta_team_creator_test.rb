require "test_helper"

class UstaTeamCreatorTest < ActiveSupport::TestCase
  # Same layout as a TennisLink Team Summary export, made-up data.
  HTML = <<~HTML.freeze
    <table>
      <tr><td>Section</td><td>District/Area</td><td>League</td><td>Flight/SubFlight</td></tr>
      <tr><td>USTA/MIDDLE STATES</td><td>PHILADELPHIA</td><td>Adult 18 &amp; Over Winter</td><td>4.0 Women - Test Winter / Sub-Flight 1</td></tr>
      <tr><td>Captain</td><td>Co-Captain</td><td>Facility</td><td>League Date</td></tr>
      <tr><td>Cap Tester 610-555-0100 cap@example.com</td><td>Co Tester 610-555-0101 co@example.com</td><td>Test Racquet Club4 N TEST AVE TESTTOWN PA 19010</td><td>11/02/2026 - 03/31/2027 Flight Date</td></tr>
      <tr><td>11/02/2026 - 03/31/2027</td></tr>
      <tr><td>Admin's Message:</td><td>Format: 1S, 3D</td></tr>
      <tr><td>Captain's Message:</td><td></td></tr>
    </table>
    <table>
      <tr><th>Team Name</th><th>Matches Played</th><th>Points*</th><th>Sets Won</th><th>Sets Lost</th><th>Games Won</th><th>Games Lost</th><th>* Games Won %</th></tr>
      <tr><td>Rival One</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0.00%</td></tr>
      <tr><td>Test Aces Winter</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0</td><td>0.00%</td></tr>
      <tr><td></td></tr>
      <tr><td>Team Matches</td></tr>
      <tr><td>There are no match records for this team</td></tr>
      <tr><td>Players</td></tr>
      <tr><td>Player Name</td><td>NTRP</td><td>Player Name</td><td>NTRP</td></tr>
      <tr><td>Cap Tester</td><td>4</td><td>Roster Player</td><td>3.5</td></tr>
      <tr><td></td></tr>
    </table>
  HTML

  setup do
    @parsed = UstaTeamSummaryParser.parse(HTML)
    @uploader = User.create!(name: "Up Loader", email: "uploader-test@example.com")
  end

  test "reads the header without keeping phone numbers or emails" do
    assert_equal "Cap Tester", @parsed.captain
    assert_equal "Co Tester", @parsed.co_captain
    assert_equal "Test Racquet Club", @parsed.facility
    assert_equal "4 N TEST AVE TESTTOWN PA 19010", @parsed.facility_address
    assert_equal "1S, 3D", @parsed.format
  end

  test "creates the team with its format, captains, roster and standings" do
    team = UstaTeamCreator.new(@parsed, team_name: "Test Aces Winter", user: @uploader).call

    assert_equal "USTA", team.league_category
    assert_equal "USTA Adult 18 & Over Winter", team.league_name
    assert_equal 4.0, team.rating.to_f
    assert_equal "Women's", team.gender
    assert_equal "Test Racquet Club", team.home_court
    assert_equal Date.new(2026, 11, 2), team.start_date
    assert_equal "Winter 2026-27", team.season_name
    assert_equal [ [ "singles", 1 ], [ "doubles", 1 ], [ "doubles", 2 ], [ "doubles", 3 ] ], team.lineup_slot_plan.keys

    roles = team.team_memberships.includes(:user).to_h { |m| [ m.user.name, m.role ] }
    assert_equal "captain", roles["Cap Tester"]
    assert_equal "co_captain", roles["Co Tester"]
    assert_equal "player", roles["Roster Player"]
    assert_equal "player", roles["Up Loader"]
    assert_equal [ "Rival One" ], team.division_teams.map(&:name)
    assert_nil User.find_by(name: "Cap Tester").email
  end

  test "running it again reuses the team" do
    first = UstaTeamCreator.new(@parsed, team_name: "Test Aces Winter", user: @uploader).call
    again = UstaTeamCreator.new(@parsed, team_name: "Test Aces Winter", user: @uploader).call
    assert_equal first.id, again.id
    assert_equal 4, again.team_memberships.count
  end
end
