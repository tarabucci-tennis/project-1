require "test_helper"

# Tara, Nov 16 2026: numbers on different pages must not contradict each other.
class NumbersAgreeTest < ActionDispatch::IntegrationTest
  setup do
    @tara = User.create!(name: "Agree Tara", email: "agree-tara@example.com", password: "tennis-123")
    @mate = User.create!(name: "Agree Mate", email: "agree-mate@example.com")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  def line_for(match, position, result, players)
    line = match.match_lines.create!(line_type: "doubles", position: position, result: result, set1_score: "6-3")
    players.each { |u| line.match_line_players.create!(user: u) }
    line
  end

  test "team page lists team events from the calendar and its counts add up" do
    team = TennisTeam.create!(user: @tara, name: "Agree Served", league_category: "USTA")
    TeamMembership.create!(user: @tara, tennis_team: team, role: "captain")
    team.team_events.create!(title: "Over Served vs Smashers", kind: "Match", event_date: Date.current + 2)

    sign_in(@tara)
    get team_path(team)
    assert_response :success
    assert_select ".cr-sched-event .cr-sched-opp", text: "Over Served vs Smashers"
    assert_no_match(/No upcoming matches or events/, response.body)
  end

  test "hero breakdown adds up, ties show as W-L-T, and Starts becomes Next match" do
    team = TennisTeam.create!(user: @tara, name: "Agree Legacy", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @tara, tennis_team: team, role: "captain")
    team.matches.create!(opponent: "W1", match_date: 20.days.ago, result: "win")
    team.matches.create!(opponent: "L1", match_date: 13.days.ago, result: "loss")
    team.matches.create!(opponent: "T1", match_date: 6.days.ago, result: "tie")
    team.matches.create!(opponent: "Unscored", match_date: 2.days.ago)
    team.matches.create!(opponent: "Next Up", match_date: 4.days.from_now)

    sign_in(@tara)
    get team_path(team)
    assert_select ".cr-hero-stat-value", text: "1-1-1"
    assert_select ".cr-hero-stat-label", text: "Record (W-L-T)"
    assert_select ".cr-hero-stat-value", text: "5"
    assert_select ".cr-hero-breakdown", text: /3 played · 1 needs scores · 1 to play/
    assert_select ".cr-hero-stat-label", text: "Next match"
    assert_select ".cr-hero-stat-label", text: "Starts", count: 0
    assert_equal "1-1-1", team.reload.record_label
    assert_equal 50, team.win_pct
  end

  test "a season that hasn't started still says Starts" do
    team = TennisTeam.create!(user: @tara, name: "Agree Winter", league_category: "USTA")
    TeamMembership.create!(user: @tara, tennis_team: team, role: "captain")
    team.matches.create!(opponent: "Opener", match_date: 5.days.from_now)
    sign_in(@tara)
    get team_path(team)
    assert_select ".cr-hero-stat-label", text: "Starts"
  end

  test "profile: one count everywhere, league-site matches added once, no frozen seed table" do
    team = TennisTeam.create!(user: @tara, name: "Agree PCC 2", league_category: "Inter-Club", league_name: "Inter-Club")
    TeamMembership.create!(user: @tara, tennis_team: team, role: "player")
    m1 = team.matches.create!(opponent: "Laurel", match_date: Time.zone.local(2026, 5, 4, 10))
    m2 = team.matches.create!(opponent: "Dupont", match_date: Time.zone.local(2026, 5, 11, 10))
    line_for(m1, 1, "win", [ @tara, @mate ])
    line_for(m2, 2, "loss", [ @tara, @mate ])
    # Same match as m1 on the league site: must not be counted twice.
    @tara.player_matches.create!(source: "t", source_key: "a", league: "Inter-Club", division: "Cup 6",
                                 played_on: Date.new(2026, 5, 4), result: "win", line_label: "Line 1")
    # Subbed for another club's team that isn't on Court Report: counted.
    @tara.player_matches.create!(source: "t", source_key: "b", league: "Inter-Club", division: "Cup 2",
                                 played_on: Date.new(2026, 5, 18), result: "win", line_label: "Line 3",
                                 match_label: "Philadelphia Country #1 vs Overbrook")
    @tara.tennis_stats.create!(year: 2025, matches_total: 45, matches_won: 39, matches_lost: 6)

    sign_in(@tara)
    get profile_path
    assert_response :success
    assert_select ".cr-playing-stat-detail", text: "2 of 3 matches"
    assert_select ".cr-stats-scope", text: /3 matches: 2 from scores on Court Report \+ 1 from league websites/
    assert_select "#cr-advanced-stats .cr-adv-total td", text: "3"
    assert_no_match(/>45</, response.body)
    assert_match(/1 of them is the same match as a Court Report score/, response.body)
  end

  test "ratings table says its record is USTA only" do
    admin = User.create!(name: "Agree Admin", email: "agree-admin@example.com", password: "tennis-123", admin: true)
    fake = [ RatingsHistory::PlayerSummary.new(name: "Agree Admin", wins: 1, losses: 0) ]
    original = RatingsHistory.method(:player_summaries)
    RatingsHistory.define_singleton_method(:player_summaries) { |*| fake }
    begin
      sign_in(admin)
      get ratings_path
    ensure
      RatingsHistory.define_singleton_method(:player_summaries, original)
    end
    assert_select "th", text: "USTA record"
    assert_select "th", text: "USTA win %"
  end
end
