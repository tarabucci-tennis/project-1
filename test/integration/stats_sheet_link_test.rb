require "test_helper"

class StatsSheetLinkTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Sheet Captain", email: "sheet-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Sheet Team", league_category: "USTA")
    @other = TennisTeam.create!(user: @captain, name: "Other Team", league_category: "USTA",
                                stats_sheet_url: "https://docs.google.com/spreadsheets/d/OTHER/edit#gid=5")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @captain, tennis_team: @other, role: "captain")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
  end

  test "a team with no sheet of its own shows no stats sheet button" do
    get team_path(@team)
    assert_no_match "Open Full Stats Sheet", response.body
    assert_no_match "docs.google.com/spreadsheets", response.body
  end

  test "each team links only to its own sheet" do
    get team_path(@other)
    assert_select "a[href='https://docs.google.com/spreadsheets/d/OTHER/edit#gid=5']", text: /Open Full Stats Sheet/
  end

  test "a captain saves the team's sheet; non-Google links are refused" do
    patch update_info_team_path(@team), params: { tennis_team: { stats_sheet_url: " https://docs.google.com/spreadsheets/d/MINE/edit#gid=0 " } }
    assert_equal "https://docs.google.com/spreadsheets/d/MINE/edit#gid=0", @team.reload.stats_sheet_url

    patch update_info_team_path(@team), params: { tennis_team: { stats_sheet_url: "https://evil.example.com/x" } }
    assert_equal "https://docs.google.com/spreadsheets/d/MINE/edit#gid=0", @team.reload.stats_sheet_url
  end
end
