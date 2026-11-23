require "test_helper"

# Past friendlies sit behind one "Look back" menu by date (Tara, Nov 23 2026).
class FriendlyLookbackTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Look Back", email: "lookback@example.com", password: "tennis-123")
    @old = @me.organized_friendlies.create!(title: "LB Old", starts_at: 9.days.ago.change(hour: 9), ends_at: 9.days.ago.change(hour: 10))
    @new = @me.organized_friendlies.create!(title: "LB New", starts_at: 2.days.ago.change(hour: 9), ends_at: 2.days.ago.change(hour: 10))
    team = TennisTeam.create!(user: @me, name: "LB Team", league_category: "USTA")
    TeamMembership.create!(user: @me, tennis_team: team, role: "captain")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "both pages list past friendlies by date, newest first, all cards hidden until picked" do
    [ friendlies_path, teams_path(tab: "friendlies") ].each do |path|
      get path
      opts = css_select("select.cr-fr-lookback-select option").map(&:text)
      assert_match(/2 past friendlies/, opts.first, path)
      assert_match(/LB New/, opts[1], path)
      assert_match(/LB Old/, opts[2], path)
      assert_select ".cr-fr-lookback-card[hidden]", 2
    end
  end
end
