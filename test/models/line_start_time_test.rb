require "test_helper"

class LineStartTimeTest < ActiveSupport::TestCase
  test "single times get AM/PM" do
    assert_equal "10:30 AM", LineStartTime.normalize("10:30")
    assert_equal "1:00 PM", LineStartTime.normalize("1pm")
  end

  test "time ranges use an en dash, the period said once when shared" do
    assert_equal "12:00 – 1:30 PM", LineStartTime.normalize("12:00 PM to 1:30 PM")
    assert_equal "12:00 – 1:30 PM", LineStartTime.normalize("12-1:30")
    assert_equal "11:30 AM – 1:00 PM", LineStartTime.normalize("11:30 AM - 1 PM")
  end

  test "text that isn't a time is left alone" do
    assert_equal "Sept 5-6", LineStartTime.normalize("Sept 5-6")
  end

  test "bare times inside a title get AM/PM" do
    assert_equal "(D1 10:30 AM with Rachel)", LineStartTime.mark_times("(D1 10:30 with Rachel)")
    assert_equal "Clinic 9:00 am", LineStartTime.mark_times("Clinic 9:00 am")
  end

  test "ranges sort by their start" do
    assert_equal 12 * 60, LineStartTime.sort_key("12:00 – 1:30 PM")
    assert_operator LineStartTime.sort_key("10:30 AM"), :<, LineStartTime.sort_key("12:00 – 1:30 PM")
  end
end
