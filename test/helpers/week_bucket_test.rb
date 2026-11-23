require "test_helper"

# My Teams → Upcoming groups cards under "This week / Next week / Later"
# (Tara, Nov 23 2026). Weeks run Monday–Sunday on the Eastern clock.
class WeekBucketTest < ActionView::TestCase
  include ApplicationHelper

  test "groups dates into this week, next week and later" do
    travel_to Time.utc(2026, 11, 23, 15, 0) do # Monday, Nov 23 (10 AM Eastern)
      assert_equal "This week", week_bucket(Date.new(2026, 11, 23))
      assert_equal "This week", week_bucket(Date.new(2026, 11, 29)) # Sunday
      assert_equal "Next week", week_bucket(Date.new(2026, 11, 30))
      assert_equal "Next week", week_bucket(Date.new(2026, 12, 6))
      assert_equal "Later",     week_bucket(Date.new(2026, 12, 7))
      assert_equal "This week", week_bucket(Time.utc(2026, 11, 26, 10, 0))
    end
  end
end
