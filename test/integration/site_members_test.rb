require "test_helper"

# Founder-only Site members page: who made an account, how many days they've
# visited and how many times they've signed in, plus a spreadsheet download.
class SiteMembersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Founder Admin", email: "founder-mem@example.com", password: "tennis-123", admin: true)
    @member = User.create!(name: "Member Player", email: "member-mem@example.com", password: "tennis-123")
    @placeholder = User.create!(name: "Roster Only", email: "roster-only-mem@example.com")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "signing in counts a sign-in and one day visited, however many pages are opened" do
    sign_in(@member)
    get teams_path
    get profile_path
    @member.reload
    assert_equal 1, @member.sign_in_count
    assert_equal 1, @member.days_visited
    assert_not_nil @member.last_seen_at

    delete session_path
    sign_in(@member)
    @member.reload
    assert_equal 2, @member.sign_in_count
    assert_equal 1, @member.days_visited, "same day counts once"
  end

  test "a new day counts as another visit" do
    @member.update_columns(days_visited: 3, last_seen_on: 2.days.ago.to_date)
    @member.record_visit!
    assert_equal 4, @member.reload.days_visited
  end

  test "the founder sees members (not roster-only players) and can download a spreadsheet" do
    sign_in(@admin)
    get admin_members_path
    assert_response :success
    assert_match "Member Player", response.body
    assert_no_match "Roster Only", response.body
    assert_select "a[href=?]", admin_members_path(format: :csv), text: "Download spreadsheet"
    assert_select ".cr-user-menu a[href=?]", admin_members_path, text: "Site members"

    get admin_members_path(format: :csv)
    assert_response :success
    assert_match "text/csv", response.media_type
    assert_match(/attachment; filename="court-report-members-/, response.headers["Content-Disposition"])
    assert_match "\"Days visited\"", response.body
    assert_match "\"member-mem@example.com\"", response.body
  end

  test "spreadsheet cells can't run as formulas" do
    @member.update_columns(name: "=HYPERLINK(\"x\")")
    sign_in(@admin)
    get admin_members_path(format: :csv)
    assert_match "\"'=HYPERLINK(\"\"x\"\")\"", response.body
  end

  test "players can't see the members page or the founder menu" do
    sign_in(@member)
    get admin_members_path
    assert_redirected_to root_path
    get admin_members_path(format: :csv)
    assert_response :redirect
    get teams_path
    assert_select ".cr-user-menu", count: 0
  end
end
