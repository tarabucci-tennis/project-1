require "test_helper"

# The left column on every signed-in page: your name and its menu, search,
# the My Teams views, Explore, your current teams and + New Team.
class SidebarTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Tara Tester", email: "sb-tara@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @me, name: "Sidebar Aces", league_category: "USTA", league_name: "USTA")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "player")
    @old = TennisTeam.create!(user: @me, name: "Old Season Club", league_category: "Local", league_name: "Del-Tri", archived: true)
    TeamMembership.create!(user: @me, tennis_team: @old, role: "player")
  end

  test "signed-in pages show the left column with my name, views and teams" do
    post session_path, params: { email: @me.email, password: "tennis-123" }
    get teams_path(tab: "calendar")
    assert_response :success
    assert_select ".cr-sb .cr-sb-name", text: "Tara Tester"
    assert_select ".cr-sb a.cr-sb-link.is-on[href=?]", teams_path(tab: "calendar")
    assert_select ".cr-sb a[href=?]", lookup_path
    assert_select ".cr-sb a.cr-sb-team[href=?]", team_path(@team)
    assert_select ".cr-sb a.cr-sb-team[href=?]", team_path(@old), count: 0
    assert_select ".cr-sb a[href=?]", new_team_path
    assert_select ".cr-sb form[action=?] button", session_path, text: "Sign out"
    assert_select ".cr-sb a[href=?]", admin_members_path, count: 0
    assert_select "button.cr-sb-burger[aria-controls=cr-sidebar]"

    get team_path(@team)
    assert_select ".cr-sb a.cr-sb-team.is-on[href=?]", team_path(@team)
  end

  test "signed-out pages have no left column" do
    get login_path
    assert_select ".cr-sb", count: 0
    assert_select ".cr-sb-burger", count: 0
  end
end
