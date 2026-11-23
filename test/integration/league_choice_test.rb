require "test_helper"

# Create a Team → League menu (Tara, Nov 23 2026): her leagues by name, other
# areas' leagues (ALTA, NorCal, HLTA, NITTL), a local/club league, or Other.
class LeagueChoiceTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "League Chooser", email: "league-chooser@example.com", password: "tennis-123")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "the menu lists her leagues, other areas and Other" do
    get new_team_path
    %w[USTA Del-Tri Bux-Mont].each { |l| assert_select "select[name=league_choice] option", text: l }
    assert_select "select[name=league_choice] option", text: "Inter-Club (Cup)"
    assert_select "select[name=league_choice] option", text: "ALTA (Atlanta)"
    assert_select "select[name=league_choice] option", text: /NorCal/
    assert_select "select[name=league_choice] option", text: "HLTA (Houston)"
    assert_select "select[name=league_choice] option", text: /NITTL/
    assert_select "select[name=league_choice] option", text: /Other league/
    assert_select "optgroup[label='Other areas']"
  end

  test "each choice stores the league the rest of the app reads" do
    {
      "usta"    => [ "USTA", "USTA", :sets ],
      "deltri"  => [ "Local", "Del-Tri", :games ],
      "buxmont" => [ "Local", "Bux-Mont", :games ],
      "cup"     => [ "Inter-Club", "Cup", :sets ],
      "alta"    => [ "Local", "ALTA", :sets ],
      "norcal"  => [ "USTA", "USTA", :sets ],
      "hlta"    => [ "Local", "HLTA", :sets ]
    }.each do |key, (category, group, rule)|
      post create_team_path, params: { name: "LC #{key}", league_choice: key }
      team = TennisTeam.find_by!(name: "LC #{key}")
      assert_equal category, team.league_category, key
      assert_equal group, team.league_group, key
      assert_equal rule, team.line_rule, key
    end
    assert_equal "win_loss", TennisTeam.find_by!(name: "LC buxmont").standings_layout
  end

  test "Other uses the typed league name; blank is refused" do
    post create_team_path, params: { name: "LC Mine", league_choice: "other", league_name: "Main Line Women's League" }
    team = TennisTeam.find_by!(name: "LC Mine")
    assert_equal "Main Line Women's League", team.league_group

    assert_no_difference -> { TennisTeam.count } do
      post create_team_path, params: { name: "LC Blank", league_choice: "other", league_name: "" }
    end
    assert_response :unprocessable_entity
  end

  test "copying a team pre-selects its league" do
    old = TennisTeam.create!(user: @me, name: "LC Old", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @me, tennis_team: old, role: "captain")
    get new_team_path(from: old.id)
    assert_select "select[name=league_choice] option[selected][value=buxmont]"
  end
end
