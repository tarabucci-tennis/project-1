require "test_helper"

class DeleteTeamTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(name: "Team Owner", email: "del-owner@example.com", password: "tennis-123")
    @player = User.create!(name: "Del Player", email: "del-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @owner, name: "Over Served Test", league_category: "USTA")
    TeamMembership.create!(user: @owner, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @team.matches.create!(opponent: "Love Hurts", match_date: 3.weeks.from_now)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "whoever added a team with no scores can delete it; players' accounts stay" do
    sign_in(@owner)
    get team_path(@team)
    assert_select "button", text: "Delete team"

    assert_difference -> { TennisTeam.count } => -1, -> { Match.count } => -1, -> { User.count } => 0 do
      delete team_path(@team)
    end
    assert_redirected_to teams_path
  end

  test "a plain player can't delete the team" do
    sign_in(@player)
    get team_path(@team)
    assert_select "button", text: "Delete team", count: 0
    assert_no_difference -> { TennisTeam.count } do
      delete team_path(@team)
    end
  end

  test "a team with scores entered can't be deleted" do
    @team.matches.first.update!(result: "win")
    sign_in(@owner)
    get team_path(@team)
    assert_select "button", text: "Delete team", count: 0
    assert_no_difference -> { TennisTeam.count } do
      delete team_path(@team)
    end
  end
end
