require "test_helper"

class TeamSyncTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @player = User.create!(name: "Sync Player", email: "sync-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @player, name: "Sync Club", league_category: "Local", league_name: "Del-Tri",
                               tenniscores_url: "https://deltri.tenniscores.com/?mod=x&team=y")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    post session_path, params: { email: @player.email, password: "tennis-123" }
    Rails.cache.delete(TeamSyncJob.key(@team.id))
  end

  test "league-site teams show Sync scores; any teammate can start it" do
    get team_path(@team)
    assert_select "form[action=?] button", sync_scores_team_path(@team), text: /Sync scores/
    assert_enqueued_with(job: TeamSyncJob, args: [ @team.id ]) do
      post sync_scores_team_path(@team)
    end
    assert_redirected_to team_path(@team)
  end

  test "a second tap while syncing doesn't start another run" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(TeamSyncJob.key(@team.id), { state: "running", started_at: Time.current })
    assert_no_enqueued_jobs(only: TeamSyncJob) { post sync_scores_team_path(@team) }
  ensure
    Rails.cache = original
  end

  test "teams without a league site get no button" do
    @team.update!(tenniscores_url: nil)
    get team_path(@team)
    assert_select "form[action=?]", sync_scores_team_path(@team), count: 0
  end

  test "scorecards with accented names or arrows read as text, not raw bytes" do
    body = "<td>1 Jos\xC3\xA9 Smith \xE2\x86\x91</td>".b
    fixed = body.dup.force_encoding(Encoding::UTF_8).scrub
    assert_equal "1 José Smith ↑", fixed.gsub(/<\/?td>/, "")
    assert_nothing_raised { fixed.gsub(/[↑↓]/, " ") }
  end
end
