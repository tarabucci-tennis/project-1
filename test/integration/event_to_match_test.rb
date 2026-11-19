require "test_helper"

# Captains turn a calendar entry into a real match so it can get a score.
class EventToMatchTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "E2M Cap", email: "e2m-cap@example.com", password: "tennis-123")
    @player = User.create!(name: "E2M Player", email: "e2m-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Over Served", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @event = @team.team_events.create!(title: "Over Served vs Smashers", kind: "Match",
                                       event_date: @date = Date.current + 7, start_time: "6:30 PM",
                                       location: "Legacy Tennis", notes: "Bring balls")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "captain sees the button and the event becomes a match with the same details" do
    sign_in(@captain)
    get team_path(@team)
    assert_select "form[action='#{make_match_team_event_path(@team, @event)}']"

    assert_difference -> { @team.matches.count } => 1, -> { @team.team_events.count } => -1 do
      post make_match_team_event_path(@team, @event)
    end
    match = @team.matches.last
    assert_redirected_to edit_team_match_path(@team, match)
    assert_equal "Smashers", match.opponent
    assert_equal Time.zone.local(@date.year, @date.month, @date.day, 18, 30), match.match_date
    assert_equal "6:30 PM", match.match_time
    assert_equal "Legacy Tennis", match.location
    assert_equal "Bring balls", match.notes
  end

  test "players don't see the button and can't convert" do
    sign_in(@player)
    get team_path(@team)
    assert_select "form[action='#{make_match_team_event_path(@team, @event)}']", count: 0

    assert_no_difference -> { @team.matches.count } do
      post make_match_team_event_path(@team, @event)
    end
    assert TeamEvent.exists?(@event.id)
  end

  test "opponent and time parsing" do
    assert_equal "Smashers", TeamEventsController.opponent_from("vs. Smashers", "Over Served")
    assert_equal "Kinetix Deuces Wild", TeamEventsController.opponent_from("Kinetix Deuces Wild", "Over Served")
    assert_equal "Smashers", TeamEventsController.opponent_from("Over Served v Smashers", "Over Served")
    assert_equal Time.zone.local(2026, 11, 19, 12), TeamEventsController.match_time_for(Date.new(2026, 11, 19), "Morning")
    assert_equal Time.zone.local(2026, 11, 19, 19), TeamEventsController.match_time_for(Date.new(2026, 11, 19), "7 PM")
  end
end
