require "test_helper"

class MyTeamsFriendliesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Fran Friendly", email: "my-teams-fr@example.com", password: "tennis-123")
    team = TennisTeam.create!(name: "Test Aces", league_category: "USTA", user: @user)
    TeamMembership.create!(user: @user, tennis_team: team, role: "captain")
    Friendly.create!(organizer: @user, starts_at: 3.days.from_now, courts: 1, title: "Thursday hit")
    team.team_events.create!(title: "Serve clinic", kind: "clinic", event_date: 5.days.from_now.to_date)
    team.team_events.create!(title: "Old drill", kind: "practice", event_date: 6.days.from_now.to_date)
    post session_path, params: { email: @user.email, password: "tennis-123" }
  end

  test "friendlies and clinics show on Coming Up and their own tab; practice reads as Friendly" do
    get teams_path
    assert_response :success
    body = response.body
    assert_match "Friendlies &amp; Clinics", body
    # 3 cards (friendly, clinic, old practice) on Coming Up + the same 3 on the new tab.
    assert_select ".cr-my-week-card-event", 6
    assert_match "Thursday hit", body
    assert_match "Serve clinic", body
    assert_no_match(/>\s*Practice\s*</, body)
    assert_no_match(/PRACTICE/, body)
  end

  test "a captain's new calendar event defaults to a friendly" do
    team = TennisTeam.find_by(name: "Test Aces")
    post team_events_path(team), params: { event_date: Date.current + 7 }
    assert_equal "friendly", team.team_events.order(:id).last.kind
  end
end
