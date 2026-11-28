require "test_helper"

# QA Nov 27 2026: at 7:29 PM Eastern (00:29 UTC the next day) the calendar marked
# tomorrow as today. "Today" now follows the Eastern clock.
class PlayClockTodayTest < ActiveSupport::TestCase
  test "today is the Eastern date, not the server's UTC date" do
    travel_to Time.utc(2026, 11, 28, 0, 29) do
      assert_equal Date.new(2026, 11, 28), Date.current
      assert_equal Date.new(2026, 11, 27), PlayClock.today
    end
  end

  test "tomorrow's match hasn't started yet at 7:29 PM Eastern" do
    team = TennisTeam.create!(user: User.create!(name: "Clock U", email: "clock-u@example.com"), name: "Clock Club")
    match = team.matches.create!(opponent: "Night", match_date: Time.utc(2026, 11, 28, 10))
    travel_to Time.utc(2026, 11, 28, 0, 29) do
      assert_not match.started?
    end
  end
end
