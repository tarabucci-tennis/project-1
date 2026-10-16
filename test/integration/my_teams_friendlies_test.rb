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

  test "friendlies and clinics show on Upcoming and the Friendlies tab; practice reads as Friendly" do
    get teams_path
    assert_response :success
    body = response.body
    assert_select ".cr-home-tab", text: "Friendlies"
    assert_select ".cr-home-tab", text: "Upcoming"
    # 3 cards (friendly, clinic, old practice) on Upcoming + the same 3 on the Friendlies tab.
    assert_select ".cr-my-week-card-event", 6
    assert_match "Thursday hit", body
    assert_match "Serve clinic", body
    assert_no_match(/>\s*Practice\s*</, body)
    assert_no_match(/PRACTICE/, body)
  end

  test "every friendly and clinic card has calendar and share buttons" do
    get teams_path
    assert_select ".cr-my-week-card-event .cr-my-week-right a.cr-cal-btn[href^='https://calendar.google.com']", 6
    assert_select ".cr-my-week-card-event .cr-my-week-right button.cr-share-icon[data-share-text]", 6
    assert_select "button.cr-share-icon[data-share-text*='Clinic: Serve clinic']"
    assert_select "button.cr-share-icon[data-share-url*='/f/']"
  end

  test "a captain's new calendar event defaults to a friendly" do
    team = TennisTeam.find_by(name: "Test Aces")
    post team_events_path(team), params: { event_date: Date.current + 7 }
    assert_equal "friendly", team.team_events.order(:id).last.kind
  end
end
