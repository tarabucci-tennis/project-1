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
end
