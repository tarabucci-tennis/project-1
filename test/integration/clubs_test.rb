require "test_helper"

class ClubsTest < ActionDispatch::IntegrationTest
  setup do
    @club = Club.create!(league: "Bux-Mont", name: "Upper Dublin", address: "680 Tennis Ave, Ambler, PA 19002", aliases: "Upper Dublin")
    @player = User.create!(name: "Plain Player", email: "clubs-player@example.com", password: "tennis-123")
    @admin = User.create!(name: "Club Admin", email: "clubs-admin@example.com", password: "tennis-123", admin: true)
    @team = TennisTeam.create!(user: @admin, name: "Advantage Test", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "the Standings tab lists the league's clubs with addresses" do
    sign_in(@player)
    get team_path(@team)
    assert_match "Bux-Mont Club Locations", response.body
    assert_select ".cr-clubs-addr span", text: "680 Tennis Ave"
    assert_select ".cr-clubs-addr span", text: "Ambler, PA 19002"
    assert_no_match "+ Add a club", response.body
  end

  test "a plain player can't edit a club" do
    sign_in(@player)
    patch club_path(@club), params: { club: { address: "Hacked" }, team_id: @team.id }
    assert_equal "680 Tennis Ave, Ambler, PA 19002", @club.reload.address
  end

  test "an admin edits, adds and removes clubs" do
    sign_in(@admin)
    patch club_path(@club), params: { club: { address: "700 New Rd, Ambler, PA 19002" }, team_id: @team.id }
    assert_redirected_to team_path(@team, tab: "standings", anchor: "clubs")
    assert_equal "700 New Rd, Ambler, PA 19002", @club.reload.address

    post clubs_path, params: { league: "Bux-Mont", team_id: @team.id,
                               club: { name: "New Club", address: "1 Main St, Doylestown, PA 18901", aliases: "Newbie, NC" } }
    assert_equal "Newbie, NC", Club.find_by(name: "New Club").aliases

    delete club_path(@club), params: { team_id: @team.id }
    assert_nil Club.find_by(id: @club.id)
  end
end
