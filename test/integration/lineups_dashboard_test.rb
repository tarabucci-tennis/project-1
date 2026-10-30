require "test_helper"

# Lineups page: one card, one row per upcoming match with its status and one
# action; a player asked to confirm gets I'm in / Can't play.
class LineupsDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Cap Tain", email: "lu-cap@example.com", password: "tennis-123")
    @me = User.create!(name: "Pat Player", email: "lu-pat@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Dash Aces", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "player")
    @open = @team.matches.create!(match_date: 3.days.from_now, opponent: "Open Club")
    @posted = @team.matches.create!(match_date: 6.days.from_now, opponent: "Posted Club")
    lineup = @posted.create_lineup!(published: true, published_at: Time.current)
    lineup.lineup_slots.create!(line_type: "doubles", position: 2, user: @me, confirmation: "pending")
  end

  test "a captain sees every match in one card with Set lineup / Edit lineup" do
    post session_path, params: { email: @cap.email, password: "tennis-123" }
    get lineups_dashboard_path
    assert_response :success
    assert_select ".cr-lu-card .cr-lu-row", 2
    assert_select ".cr-lu-row a.cr-lu-btn.is-primary[href=?]", edit_team_match_lineup_path(@team, @open), text: "Set lineup"
    assert_select ".cr-lu-row a.cr-lu-btn[href=?]", edit_team_match_lineup_path(@team, @posted), text: "Edit lineup"
    assert_select ".cr-lu-status", text: "Not posted"
  end

  test "a player asked to play can answer from the row" do
    post session_path, params: { email: @me.email, password: "tennis-123" }
    get lineups_dashboard_path
    assert_select ".cr-lu-status", text: "Please reply"
    assert_select ".cr-lu-reply a[href=?]", confirm_team_match_lineup_path(@team, @posted, status: "confirmed"), text: "I'm in"
    assert_select ".cr-lu-row a.cr-lu-btn", text: "View", count: 2
  end
end
