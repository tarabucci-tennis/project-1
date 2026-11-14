require "test_helper"

class TeamSubsTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Sub Captain", email: "sub-cap@example.com", password: "tennis-123")
    @player = User.create!(name: "Sub Player", email: "sub-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Sub Club", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "captain adds a sub with a note; it shows on the Subs tab and in Set Lineup" do
    sign_in(@captain)
    assert_difference "TeamSub.count", 1 do
      post team_subs_path(@team), params: { name: "  Nora   Newsub ", note: "3.5, courts 4-6" }
    end
    assert_redirected_to team_path(@team, tab: "subs")
    get team_path(@team)
    assert_select ".cr-subtab", text: "Subs"
    assert_select ".cr-subs-row .cr-subs-name", text: "Nora Newsub"
    assert_select ".cr-subs-row .cr-subs-note", text: "3.5, courts 4-6"

    match = @team.matches.create!(match_date: 3.days.from_now, opponent: "Rivals")
    get edit_team_match_lineup_path(@team, match)
    assert_select "option", text: "Nora Newsub (sub)"
  end

  test "someone who subbed in a lineup is listed and can be saved; roster players can't be subs" do
    sign_in(@captain)
    walk_in = User.create!(name: "Wanda Walkin")
    match = @team.matches.create!(match_date: 2.days.ago, opponent: "Old Rivals")
    lineup = match.create_lineup!
    lineup.lineup_slots.create!(line_type: "doubles", position: 1, user: walk_in)

    get team_path(@team)
    assert_select ".cr-subs-row", text: /Wanda Walkin.*Subbed 1 time/m
    post team_subs_path(@team), params: { user_id: walk_in.id }
    assert @team.team_subs.exists?(user: walk_in)

    assert_no_difference "TeamSub.count" do
      post team_subs_path(@team), params: { name: "Sub Player" }
    end
    assert_match "already on the roster", flash[:alert]
  end

  test "players see the list but can't change it" do
    @team.team_subs.create!(user: User.create!(name: "Listed Sub"))
    sign_in(@player)
    get team_path(@team)
    assert_select ".cr-subs-row .cr-subs-name", text: "Listed Sub"
    assert_select ".cr-subs-add", 0
    assert_no_difference "TeamSub.count" do
      post team_subs_path(@team), params: { name: "Sneaky Sub" }
    end
    sub = @team.team_subs.first
    assert_no_difference "TeamSub.count" do
      delete team_sub_path(@team, sub)
    end
  end

  test "captain removes a sub" do
    sub = @team.team_subs.create!(user: User.create!(name: "Gone Sub"))
    sign_in(@captain)
    assert_difference "TeamSub.count", -1 do
      delete team_sub_path(@team, sub)
    end
  end
end
