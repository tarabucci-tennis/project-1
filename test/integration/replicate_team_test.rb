require "test_helper"

# New Team → "Start from a previous team" (Tara, Nov 23 2026): copy a team you
# captained into a new season. The old team is never changed.
class ReplicateTeamTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Rep Captain", email: "rep-cap@example.com", password: "tennis-123")
    @co  = User.create!(name: "Rep Co", email: "rep-co@example.com")
    @pl  = User.create!(name: "Rep Player", email: "rep-pl@example.com")
    @old_pl = User.create!(name: "Rep Archived", email: "rep-old@example.com")
    @old = TennisTeam.create!(user: @cap, name: "Rep Aces", league_category: "USTA", league_name: "USTA Adult 40 & Over",
                              team_type: "Adult 40+", home_court: "Bryn Mawr Racquet Club", line_format: "1S+3D",
                              season_name: "Spring 2026", tenniscores_url: "https://example.com/old")
    TeamMembership.create!(user: @cap, tennis_team: @old, role: "captain")
    TeamMembership.create!(user: @co,  tennis_team: @old, role: "co_captain")
    TeamMembership.create!(user: @pl,  tennis_team: @old, role: "player")
    TeamMembership.create!(user: @old_pl, tennis_team: @old, role: "player", archived_season: "Fall 2025")
    @old.matches.create!(opponent: "Rep Opp", match_date: Date.current - 30)
    post session_path, params: { email: @cap.email, password: "tennis-123" }
  end

  test "picking a previous team fills the form and offers its roster" do
    get new_team_path(from: @old.id)
    assert_select "select.cr-replicate-select option", text: /Rep Aces/
    assert_select "input[name=from_team_id][value='#{@old.id}']"
    assert_select "input[name=name][value='Rep Aces']"
    assert_select ".cr-replicate-check", text: /2 players/
  end

  test "creating from a previous team copies details and current roster, not matches or links" do
    assert_difference -> { TennisTeam.count }, 1 do
      post create_team_path, params: { from_team_id: @old.id, copy_roster: "1", name: "Rep Aces Winter",
                                       league_category: "USTA", season_name: "Winter 2027" }
    end
    team = TennisTeam.order(:id).last
    assert_equal "Rep Aces Winter", team.name
    assert_equal "Winter 2027", team.season_name
    assert_equal "Bryn Mawr Racquet Club", team.home_court
    assert_equal "1S+3D", team.line_format
    assert_nil team.tenniscores_url
    assert_equal 0, team.matches.count
    roles = team.team_memberships.includes(:user).to_h { |m| [ m.user.name, m.role ] }
    assert_equal({ "Rep Captain" => "captain", "Rep Co" => "co_captain", "Rep Player" => "player" }, roles)
    # The old team is untouched.
    assert_equal 4, @old.team_memberships.count
    assert_equal 1, @old.matches.count
  end

  test "unchecking the roster box creates the team with just you" do
    post create_team_path, params: { from_team_id: @old.id, name: "Rep Solo", league_category: "USTA" }
    assert_equal 1, TennisTeam.find_by(name: "Rep Solo").team_memberships.count
  end

  test "you can't copy a team you only play on" do
    other_cap = User.create!(name: "Rep Other", email: "rep-other@example.com")
    theirs = TennisTeam.create!(user: other_cap, name: "Rep Theirs", league_category: "USTA", home_court: "Secret Club")
    TeamMembership.create!(user: other_cap, tennis_team: theirs, role: "captain")
    TeamMembership.create!(user: @cap, tennis_team: theirs, role: "player")
    get new_team_path
    assert_select "select.cr-replicate-select option", text: /Rep Theirs/, count: 0
    post create_team_path, params: { from_team_id: theirs.id, copy_roster: "1", name: "Rep Sneaky", league_category: "USTA" }
    sneaky = TennisTeam.find_by(name: "Rep Sneaky")
    assert_nil sneaky.home_court
    assert_equal 1, sneaky.team_memberships.count
  end
end
