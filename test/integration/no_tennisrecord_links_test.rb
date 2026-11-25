require "test_helper"

# Tara, Nov 24 2026: roster "Matches" opened TennisRecord, by name, and showed the
# wrong Diane Walsh (Vancouver, WA). Court Report never links to TennisRecord now:
# names and Matches go to the player's own Court Report page.
class NoTennisrecordLinksTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Roster Me", email: "roster-me@example.com", password: "tennis-123")
    @mate = User.create!(name: "Diane Walsh", email: "dw-test@example.com", ntrp_rating: 4.5)
    @team = TennisTeam.create!(user: @me, name: "Roster Club", league_category: "USTA", league_name: "USTA Adult 18+")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @mate, tennis_team: @team, role: "player")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "team page has no TennisRecord links; Matches opens the Court Report profile" do
    get team_path(@team)
    assert_response :success
    assert_no_match(/tennisrecord\.com/i, response.body)
    assert_select "a.cr-roster-history-link[href=?]", player_path(@mate, anchor: "league-history"), text: "Matches"
    assert_select "a.cr-roster-name[href=?]", player_path(@mate)
  end

  test "Captain tab Player Analytics has a Profile column linking to Court Report" do
    match = @team.matches.create!(opponent: "Rivals", match_date: 3.days.ago, result: "win")
    line = match.match_lines.create!(line_type: "doubles", position: 1, result: "win", set1_score: "6-2", set2_score: "6-3")
    line.match_line_players.create!(user: @mate)
    get team_path(@team)
    assert_no_match(/tennisrecord\.com/i, response.body)
    tables = css_select(".cr-captain-analytics-table")
    analytics = tables.find { |t| t.text.include?("W-L") }
    assert analytics, "Player Analytics table should render for a captain"
    assert_includes analytics.css(".cr-captain-analytics-header").text, "Profile"
    assert analytics.css("a[href='#{player_path(@mate)}']").size >= 2, "name and Profile both link to the profile"
  end
end
