require "test_helper"

class MakeCaptainTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Cap One", email: "make-cap-1@example.com", password: "tennis-123")
    @player = User.create!(name: "New Cap", email: "make-cap-2@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Captain Test", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @member = TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "a captain adds another captain and stays captain" do
    sign_in(@captain)
    post make_captain_team_path(@team, user_id: @player.id)
    assert_redirected_to team_path(@team, tab: "roster")
    assert_equal "captain", @member.reload.role
    assert_equal "captain", @team.team_memberships.find_by(user: @captain).role
  end

  test "a player can't make anyone captain" do
    sign_in(@player)
    post make_captain_team_path(@team, user_id: @player.id)
    assert_equal "player", @member.reload.role
  end
end
