require "test_helper"

# QA list Priority 1 (#1, #3, #4): the team page's counts agree with what it
# lists and with Calendar/Upcoming.
class TeamPageCountsTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Count Cap", email: "count-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Count Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    post session_path, params: { email: @cap.email, password: "tennis-123" }
  end

  test "calendar-added league matches show on the team page and in its counts" do
    @team.team_events.create!(title: "Count Club vs Rivals (Away)", kind: "League match", event_date: Date.current + 3)
    @team.team_events.create!(title: "Serve clinic", kind: "clinic", event_date: Date.current + 4)
    get team_path(@team)
    assert_select ".cr-hero-stat", text: /1\s*Matches/
    assert_select ".cr-stat-card", text: /1\s*Scheduled/
    assert_select ".cr-sched-events .cr-my-week-card-event", 2
    assert_no_match(/No upcoming matches\./, response.body)
    assert_select ".cr-hero-stat", text: /Starts/
  end

  test "match count leaves out playoff rounds; Next match once games are played; ties in the record" do
    @team.matches.create!(match_date: 10.days.ago, opponent: "A", result: "win")
    @team.matches.create!(match_date: 9.days.ago, opponent: "B", result: "tie")
    @team.matches.create!(match_date: 5.days.from_now, opponent: "C")
    @team.matches.create!(match_date: 30.days.from_now, opponent: "Playoffs (opponent TBD)", playoff_level: "Districts")
    get team_path(@team)
    assert_select ".cr-hero-stat", text: /3\s*Matches/
    assert_select ".cr-hero-stat", text: /1-0-1\s*Record \(W-L-T\)/
    assert_select ".cr-hero-stat", text: /Next match/
    assert_equal "1-0-1", @team.reload.record_label
  end
end
