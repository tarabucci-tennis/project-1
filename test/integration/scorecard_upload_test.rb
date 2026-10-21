require "test_helper"
require_relative "../services/usta_scorecard_import_test"

# Any teammate can upload one match's TennisLink Scorecard (Send To Excel);
# the team-wide Team / Match Summary stays captains-only.
class ScorecardUploadTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(name: "Card Owner", email: "card-owner@example.com", password: "tennis-123")
    @player = User.create!(name: "Card Player", email: "card-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @owner, name: "Test Hards", league_category: "USTA", league_name: "USTA Adult Tri-Level")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @match = @team.matches.create!(match_date: Time.zone.local(2026, 9, 30, 12), opponent: "Rival Aces",
                                   result: "loss", score_summary: "1-2")
    post session_path, params: { email: @player.email, password: "tennis-123" }
  end

  def upload(html)
    file = Tempfile.new([ "card", ".xls" ])
    file.write(html)
    file.rewind
    post usta_upload_team_path(@team), params: { file: Rack::Test::UploadedFile.new(file.path, "application/vnd.ms-excel") }
  end

  test "the result pop-up offers the Send To Excel upload, with no scorecard links" do
    get team_path(@team)
    assert_select "a[href=?]", usta_upload_team_path(@team), text: "Upload Send To Excel file"
    assert_no_match "Official scorecard", response.body
    assert_no_match "Paste the TennisLink scorecard link", response.body
  end

  test "a player can preview a match scorecard" do
    upload(UstaScorecardImportTest::HTML)
    assert_response :success
    assert_match "Check before saving", response.body
    assert_no_match "Scores are already added", response.body
  end

  test "re-uploading warns that the scores already there get replaced" do
    @match.match_lines.create!(position: 1, line_type: "doubles", result: "win")
    upload(UstaScorecardImportTest::HTML)
    assert_response :success
    assert_match "Scores are already added for this match.", response.body
    assert_match "Are you sure you want to replace them", response.body
    assert_select "button[onclick*=confirm]", text: /Replace scores/
  end

  test "a player can't upload a Team Summary" do
    upload("<table><tr><td>Team Summary</td></tr></table>")
    assert_redirected_to usta_upload_team_path(@team)
    assert_equal UstaUploadsController::CAPTAINS_ONLY, flash[:alert]
  end

  test "someone not on the team can't upload" do
    outsider = User.create!(name: "Outsider", email: "card-out@example.com", password: "tennis-123")
    post session_path, params: { email: outsider.email, password: "tennis-123" }
    get usta_upload_team_path(@team)
    assert_redirected_to teams_path
  end
end
