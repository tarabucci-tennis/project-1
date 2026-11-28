require "test_helper"

# QA Nov 27 2026: at 7:29 PM Eastern the My Teams calendar marked Sat Nov 28 as today.
class CalendarTodayTest < ActionDispatch::IntegrationTest
  test "today's square follows the Eastern date after 7 PM" do
    me = User.create!(name: "Cal Today", email: "cal-today@example.com", password: "tennis-123")
    team = TennisTeam.create!(user: me, name: "Cal Club")
    TeamMembership.create!(user: me, tennis_team: team, role: "captain")
    travel_to Time.utc(2026, 11, 28, 0, 29) do
      post session_path, params: { email: me.email, password: "tennis-123" }
      get teams_path(month: "2026-11")
      today = css_select(".cr-dash-cal-day-today")
      assert_equal 1, today.size
      assert_match(/November 27/, today.first["aria-label"])
    end
  end
end
