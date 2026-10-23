require "test_helper"

# Booking a friendly: date + start/end time dropdowns, with 90 min / 2 hr /
# Not sure shortcuts.
class FriendlyTimesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Time Keeper", email: "fr-times@example.com", password: "tennis-123")
    post session_path, params: { email: @user.email, password: "tennis-123" }
  end

  test "the form shows date, start and end time dropdowns and the shortcuts" do
    get new_friendly_path
    assert_response :success
    assert_select "input[type=date][name='friendly[start_date]']"
    assert_select "select[name='friendly[start_time]'] option[value='15:00']", text: "3:00 PM"
    assert_select "select[name='friendly[end_time]'] option[value='']", text: "Not sure"
    assert_select "button.cr-fr-length-chip", text: "90 min"
    assert_select "button.cr-fr-length-chip", text: "2 hr"
    assert_select "button.cr-fr-length-chip", text: "Not sure"
    assert_no_match "1½ hours", response.body
    start = css_select("select[name='friendly[start_time]'] option[selected]").first["value"]
    finish = css_select("select[name='friendly[end_time]'] option[selected]").first["value"]
    to_min = ->(t) { h, m = t.split(":").map(&:to_i); h * 60 + m }
    assert_equal 90, (to_min.(finish) - to_min.(start)) % (24 * 60), "a new booking starts as 90 min"
  end

  test "booking saves the picked start and end times" do
    post friendlies_path, params: { friendly: { start_date: "2026-11-07", start_time: "15:00", end_time: "16:30", sets_count: 3 } }
    friendly = Friendly.order(:id).last
    assert_redirected_to friendly_path(friendly)
    assert_equal Time.zone.local(2026, 11, 7, 15, 0), friendly.starts_at
    assert_equal Time.zone.local(2026, 11, 7, 16, 30), friendly.ends_at
  end

  test "Not sure leaves the end time empty" do
    post friendlies_path, params: { friendly: { start_date: "2026-11-07", start_time: "09:00", end_time: "", sets_count: 2 } }
    assert_nil Friendly.order(:id).last.ends_at
  end

  test "editing shows the saved times picked" do
    friendly = @user.organized_friendlies.create!(starts_at: Time.zone.local(2026, 11, 7, 9, 0), end_time: "11:00")
    get edit_friendly_path(friendly)
    assert_select "input[name='friendly[start_date]'][value='2026-11-07']"
    assert_select "select[name='friendly[start_time]'] option[selected][value='09:00']"
    assert_select "select[name='friendly[end_time]'] option[selected][value='11:00']"
  end
end
