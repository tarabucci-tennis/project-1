require "test_helper"

# The top-bar search finds pages, teams, players, matches and friendlies a
# player can already see, and nothing from leagues they don't play in.
class SiteSearchTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Searcher Sam", email: "search-sam@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @me, name: "Lobster Lobbers", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @me, tennis_team: @team, role: "player")
    @mate = User.create!(name: "Penelope Partner", email: "penelope-search@example.com")
    TeamMembership.create!(user: @mate, tennis_team: @team, role: "player")
    @team.matches.create!(match_date: 5.days.from_now, opponent: "Penn Oaks 2", location: "Brandywine Racquet Club")
    Friendly.create!(organizer: @me, starts_at: 3.days.from_now, title: "Penny's Saturday hit")

    other = User.create!(name: "Penny Elsewhere", email: "penny-else@example.com")
    far = TennisTeam.create!(user: other, name: "Far Away Club", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: other, tennis_team: far, role: "player")

    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "the left column has a search box, and the top bar has no My Teams" do
    get teams_path
    assert_select "form.cr-sb-search[action=?] input[name=q]", search_path
    assert_select ".cr-header-my-teams", count: 0
  end

  test "finds players, matches and friendlies in my leagues, not other leagues" do
    get search_path(q: "pen")
    assert_response :success
    assert_select "a.cr-search-row[href=?]", player_path(@mate)
    assert_match "Lobster Lobbers vs. Penn Oaks 2", response.body
    assert_match "Penny&#39;s Saturday hit", response.body
    assert_no_match "Penny Elsewhere", response.body
  end

  test "finds my team and pages like Standings" do
    get search_path(q: "lobster")
    assert_select ".cr-search-rowlink[href=?]", team_path(@team)
    get search_path(q: "standings")
    assert_select "a.cr-search-row[href=?]", teams_path(tab: "standings")
  end

  test "searching by club finds the match" do
    get search_path(q: "brandywine")
    assert_match "Penn Oaks 2", response.body
  end

  test "an empty search just shows the box" do
    get search_path
    assert_response :success
    assert_select "input.cr-search-page-input"
  end
end
