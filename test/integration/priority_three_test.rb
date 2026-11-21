require "test_helper"

# Tara, Nov 17 2026 — Priority 3: names, labels and duplicates.
class PriorityThreeTest < ActionDispatch::IntegrationTest
  setup do
    @tara = User.create!(name: "P3 Tara", email: "p3-tara@example.com", password: "tennis-123", admin: true)
    @now = TennisTeam.create!(user: @tara, name: "P3 Legacy 1", league_category: "Local", league_name: "Del-Tri")
    @old = TennisTeam.create!(user: @tara, name: "P3 Pour Decisions", league_category: "USTA", archived: true)
    TeamMembership.create!(user: @tara, tennis_team: @now, role: "player")
    TeamMembership.create!(user: @tara, tennis_team: @old, role: "player")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "17: Players & Teams lists current teams under Your Teams, past ones separately" do
    sign_in(@tara)
    get lookup_path
    assert_select ".cr-standings-head-title", text: "Your Teams (1)"
    assert_select ".cr-lookup-past .cr-standings-head-title", text: "Your Past Seasons (1)"
    assert_select ".cr-lookup-past", text: /P3 Pour Decisions/
  end

  test "18: friendlies say how many more are needed instead of 0 courts; one button label" do
    f = Friendly.create!(organizer: @tara, title: "Singles friendly", starts_at: 2.days.from_now, token: "p3tok")
    f.spots.create!(name: "P3 Tara", user: @tara) if f.respond_to?(:spots)
    sign_in(@tara)
    get friendlies_path
    assert_select ".cr-band-note", text: /signed up · \d more for a court/
    assert_no_match(/0 courts/, response.body)
    assert_select "a", text: "+ Book a friendly"
    assert_select "a", text: "+ New friendly", count: 0
  end

  test "19: placeholder names never become players; notes in brackets are dropped" do
    assert_nil RatedLine.clean_name("A (Default)")
    assert_nil RatedLine.clean_name("N")
    assert_nil RatedLine.clean_name("Default (no opponents)")
    assert_equal "Nancy Krouse", RatedLine.clean_name("Nancy Krouse (timed match)")
    assert_equal "Jo Li", RatedLine.clean_name("Jo Li")
  end

  test "20: Lineups shows the year, tells repeat meetings apart, and names teams with nothing ahead" do
    idle = TennisTeam.create!(user: @tara, name: "P3 Over Served", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @tara, tennis_team: idle, role: "player")
    @now.matches.create!(opponent: "Frog Hollow Orange", match_date: Time.zone.local(2026, 11, 20, 10), home_away: "home")
    @now.matches.create!(opponent: "Frog Hollow Orange", match_date: Time.zone.local(2027, 2, 5, 10))
    travel_to Time.zone.local(2026, 11, 17, 9) do
      sign_in(@tara)
      get lineups_dashboard_path
    end
    assert_select ".cr-lu-when", text: /Fri, Nov 20, 2026 · Home · Meeting 1 of 2/
    assert_select ".cr-lu-when", text: /Fri, Feb 5, 2027 · Meeting 2 of 2/
    assert_select ".cr-lu-none", text: /P3 Over Served/
    assert_select ".cr-lu-team", text: "P3 Pour Decisions", count: 0
  end

  test "16: the data update spells team names out in typed titles" do
    f = Friendly.create!(organizer: @tara, title: "KMA", starts_at: 3.days.ago, token: "p3kma")
    e = @now.team_events.create!(title: "Over-served vs Smashers", kind: "Match", event_date: Date.current + 1)
    m = @now.matches.create!(opponent: "overserved", match_date: 4.days.from_now)
    require Rails.root.join("db/migrate/20261117130000_spell_out_team_names_in_titles").to_s
    ActiveRecord::Migration.suppress_messages { SpellOutTeamNamesInTitles.new.up }
    assert_equal "Kiss My Ace", f.reload.title
    assert_equal "Over Served vs Smashers", e.reload.title
    assert_equal "Over Served", m.reload.opponent
  end
end

class PriorityFourBatchOneTest < ActiveSupport::TestCase
  test "one time format: however a time was typed, it reads 9:00 AM" do
    m = Match.new(match_time: "01:30 pm")
    assert_equal "1:30 PM", m.time_label
    assert_equal "9:00 AM", Match.new(match_time: "09:00 am").time_label
    assert_equal "10:30 AM", TeamEvent.new(start_time: "10:30 am").time_label
    assert_nil Match.new(match_time: "").time_label
  end

  test "league-site team names get a space before #" do
    helper = ApplicationController.helpers
    assert_equal "Delsea #2", helper.tidy_team_name("Delsea#2")
    assert_equal "Penn Oaks #1", helper.tidy_team_name("Penn Oaks #1")
  end
end
