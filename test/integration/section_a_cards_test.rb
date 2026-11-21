require "test_helper"

# Tara's live-site list, Section A (Nov 21 2026): band cards for calendar
# entries, the Friendlies page, and the Standings "Next match".
class SectionACardsTest < ActionDispatch::IntegrationTest
  setup do
    @tara = User.create!(name: "SecA Tara", email: "seca@example.com", password: "tennis-123")
    @os = TennisTeam.create!(user: @tara, name: "SecA Over Served", league_category: "Local", league_name: "Bux-Mont")
    @km = TennisTeam.create!(user: @tara, name: "SecA Winter", league_category: "USTA", league_name: "USTA Adult 40 & Over")
    [ @os, @km ].each { |t| TeamMembership.create!(user: @tara, tennis_team: t, role: "player") }
    post session_path, params: { email: @tara.email, password: "tennis-123" }
  end

  test "USTA calendar entry: Home/Away on its own line, not in the title" do
    @km.team_events.create!(title: "SecA Winter vs Ball Busters (Away)", kind: "Match", event_date: Date.current + 3, start_time: "12:00 PM")
    get teams_path(tab: "upcoming")
    assert_select ".cr-band-title-main", text: "SecA Winter"
    assert_select ".cr-band-title-vs", text: "vs. Ball Busters"
    assert_select ".cr-band-teams", text: "Away"
    assert_select ".cr-band-card", text: /\(Away\)/, count: 0
    assert_select ".cr-dash-cal-chip-text", text: /\(Away\)/, count: 0
  end

  test "a playoffs calendar entry shows the PLAYOFFS pill" do
    @os.team_events.create!(title: "Bux-Mont Playoffs", kind: "Match", event_date: Date.current + 100)
    get teams_path(tab: "upcoming")
    assert_select ".cr-band-card", text: /Bux-Mont Playoffs/ do
      assert_select ".cr-band-pill", text: "Playoffs"
    end
  end

  test "a calendar-entry match whose end time has passed is Completed and needs scores" do
    travel_to Time.utc(2026, 11, 19, 21, 11) do # 4:11 PM Eastern
      @km.team_events.create!(title: "SecA Winter vs Love Hurts", kind: "Match", event_date: Date.new(2026, 11, 19), start_time: "9:30 – 11:30 AM")
      @km.team_events.create!(title: "SecA Winter vs Late Show", kind: "Match", event_date: Date.new(2026, 11, 19), start_time: "6:00 PM")
      get teams_path(tab: "upcoming")
      assert_select ".cr-band-card", text: /Love Hurts/ do
        assert_select ".cr-band-pill", text: "Completed"
        assert_select ".cr-band-note", text: /Needs scores/
      end
      assert_select ".cr-band-card", text: /Late Show/ do
        assert_select ".cr-band-pill", text: "Upcoming"
      end
    end
  end

  test "a match flips to Completed at its end time, not at midnight or its start" do
    m = @os.matches.create!(opponent: "Smashers", match_date: Time.utc(2026, 11, 19, 9, 30), match_time: "9:30 AM")
    travel_to(Time.utc(2026, 11, 19, 15, 0)) { assert_not m.over? } # 10:00 AM Eastern
    travel_to(Time.utc(2026, 11, 19, 17, 0)) { assert m.over? }     # noon Eastern
  end

  test "the Friendlies page uses Header Band cards" do
    f = Friendly.create!(organizer: @tara, title: "SecA mixer", starts_at: Time.current + 2.days, ends_at: Time.current + 2.days + 90.minutes)
    f.spots.create!(user: @tara, name: @tara.name) if f.spots.none?
    get friendlies_path
    assert_select ".cr-band-card .cr-band-title-main", text: "SecA mixer"
    assert_select ".cr-band-card .cr-band-pill", text: "Upcoming"
    assert_select ".cr-fr-index-row", count: 0
  end

  test "standings: a team whose schedule is calendar entries shows its next match" do
    @os.team_events.create!(title: "SecA Over Served v Hitters", kind: "Match", event_date: Date.current + 5, start_time: "10:00 AM")
    get teams_path(tab: "standings")
    assert_select ".cr-st-next-opp", text: /vs Hitters/
    assert_no_match(/No schedule yet/, response.body.split("SecA Over Served").second.to_s[0, 3000])
  end

  test "title parsing" do
    assert_equal "Hitters", TeamEvent.opponent_from("Over Served v Hitters", "Over Served")
    assert_equal "Smashers", TeamEvent.opponent_from("Over Served @ Smashers", "Over Served")
    e = TeamEvent.new(title: "X vs Y (Home)", tennis_team: @os, kind: "Match", event_date: Date.current)
    assert_equal "Home", e.side
    assert_equal "X vs Y", e.title_without_side
  end
end
