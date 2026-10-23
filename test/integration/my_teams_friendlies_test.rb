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
    assert_select ".cr-home-tab", text: "Book a friendly"
    assert_select ".cr-home-tab", text: "Upcoming"
    # 3 cards (friendly, clinic, old practice) on Upcoming + the same 3 on the Friendlies tab.
    assert_select ".cr-my-week-card-event", 6
    assert_match "Thursday hit", body
    assert_match "Serve clinic", body
    assert_no_match(/>\s*Practice\s*</, body)
    assert_no_match(/PRACTICE/, body)
  end

  test "Book a friendly menu: book one, or open / edit my upcoming friendlies" do
    mine = Friendly.find_by(title: "Thursday hit")
    other = User.create!(name: "Other Org", email: "other-org-fr@example.com")
    theirs = Friendly.create!(organizer: other, starts_at: 4.days.from_now, title: "Their hit")
    theirs.spots.create!(user: @user, name: @user.name)
    get teams_path
    assert_select ".cr-home-tabs .cr-fr-menu .cr-home-tab[data-tab-key=friendlies]", text: "Book a friendly"
    assert_select ".cr-fr-menu a.cr-menu-item[href=?]", new_friendly_path, text: /Book a friendly/
    assert_select ".cr-fr-menu a.cr-fr-menu-head[href=?]", friendlies_path, text: /My friendlies/
    assert_select ".cr-page-header-actions > a", text: "Book a friendly", count: 0
    assert_select ".cr-page-header-actions .cr-fr-menu", count: 0
    assert_select ".cr-fr-tab-head", { count: 0 }, "no separate Book a friendly / All my friendlies buttons in the panel"
    assert_select ".cr-page-header-actions [data-controller=menu][data-menu-hover-value=true]", 1, "+ New Team opens on hover"
    assert_select ".cr-fr-menu a.cr-fr-menu-open[href=?]", friendly_path(mine), text: /Thursday hit/
    assert_select ".cr-fr-menu a.cr-fr-menu-edit[href=?]", edit_friendly_path(mine), text: "Edit"
    assert_select ".cr-fr-menu a.cr-fr-menu-open[href=?]", friendly_path(theirs)
    assert_select ".cr-fr-menu a.cr-fr-menu-edit[href=?]", edit_friendly_path(theirs), count: 0
  end

  test "calendar days show each event's name and link it" do
    today = Friendly.create!(organizer: @user, starts_at: Time.zone.now.beginning_of_day + 12.hours, title: "Noon hit")
    get teams_path
    assert_select ".cr-dash-cal-day .cr-dash-cal-chip-friendly[data-url=?]", friendly_path(today), text: "Noon hit"
    assert_select ".cr-dash-cal-hover[hidden]"
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
