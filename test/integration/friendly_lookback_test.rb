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

  test "a friendly from earlier today that has ended moves to Past, not Coming up" do
    now = PlayClock.now
    begin
      ended = @me.organized_friendlies.create!(title: "LB Ended Today", starts_at: now - 3.hours, ends_at: now - 1.hour)
      later = @me.organized_friendlies.create!(title: "LB Later Today", starts_at: now + 1.hour, ends_at: now + 2.hours)
      assert ended.over?
      assert_not later.over?
      [ friendlies_path, teams_path(tab: "friendlies") ].each do |path|
        get path
        assert_select "select.cr-fr-lookback-select option", text: /LB Ended Today/
        # Only its (hidden) card inside the Look back menu, not a Coming up card.
        assert_select ".cr-band-card", text: /LB Ended Today/, count: 1
        assert_select ".cr-fr-lookback-card .cr-band-card", text: /LB Ended Today/, count: 1
        assert_select "select.cr-fr-lookback-select option", text: /LB Later Today/, count: 0
      end
    end
  end

  test "a past friendly's card offers Add scores, then See scores" do
    get friendlies_path
    assert_select ".cr-fr-lookback-card a[href$='#scores']", text: "Add scores", minimum: 2
    s = @new.scores.new(court: 1, entered_by: "Jen")
    s.assign_set_boxes("set1_a" => "6", "set1_b" => "4")
    s.save!
    get friendlies_path
    assert_select ".cr-fr-lookback-card a[href$='#scores']", text: "See scores", count: 1
    assert_select ".cr-fr-lookback-card", text: /1 court scored/
  end
end
