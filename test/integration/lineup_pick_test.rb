require "test_helper"

# Set Lineup: every player is a tappable name (coloured by her Yes / No
# answer) and every spot on a line can take the tapped player.
class LineupPickTest < ActionDispatch::IntegrationTest
  test "names are coloured by availability and every spot can take a player" do
    captain = User.create!(name: "Pick Cap", email: "pick-cap@example.com", password: "tennis-123")
    team = TennisTeam.create!(user: captain, name: "Pick Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: captain, tennis_team: team, role: "captain")
    yes = User.create!(name: "Yes Player", email: "yes-pick@example.com")
    no = User.create!(name: "No Player", email: "no-pick@example.com")
    [ yes, no ].each { |u| TeamMembership.create!(user: u, tennis_team: team, role: "player") }
    match = team.matches.create!(match_date: 3.days.from_now, opponent: "Rival Club")
    Availability.create!(user: yes, match: match, status: "in")
    Availability.create!(user: no, match: match, status: "out")

    post session_path, params: { email: captain.email, password: "tennis-123" }
    get edit_team_match_lineup_path(team, match)
    assert_response :success
    assert_select "form[data-controller='lineup-pick']"
    assert_select "button.cr-lp-chip.is-yes[data-user-id='#{yes.id}']"
    assert_select "button.cr-lp-chip.is-no[data-user-id='#{no.id}']"
    spots = css_select("button.cr-lineup-spot").size
    assert spots.positive?
    assert_equal spots, css_select("select[data-lineup-pick-target='select'][data-line]").size
  end
end
