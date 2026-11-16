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

class NumbersAgreeFollowupTest < ActionDispatch::IntegrationTest
  setup do
    @joanne = User.create!(name: "Fixture Joanne", email: "fixture-joanne@example.com", password: "tennis-123")
    @mate = User.create!(name: "Fixture Mate", email: "fixture-mate@example.com")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "Joanne: 4 Court Report scores + 2 Cup 2 subs = 6, Cup 6 site rows counted once" do
    pcc2 = TennisTeam.create!(user: @joanne, name: "Philadelphia Country #2", league_category: "Inter-Club", league_name: "Inter-Club")
    usta = TennisTeam.create!(user: @joanne, name: "Fixture USTA", league_category: "USTA")
    [ [ pcc2, "Laurel Creek #1", Date.new(2026, 4, 27) ], [ pcc2, "Waynesborough #3", Date.new(2026, 5, 4) ],
      [ pcc2, "Dupont CC #1", Date.new(2026, 5, 18) ], [ usta, "Love Hurts", Date.new(2026, 5, 12) ] ].each_with_index do |(t, opp, d), i|
      m = t.matches.create!(opponent: opp, match_date: Time.zone.local(d.year, d.month, d.day, 10))
      line = m.match_lines.create!(line_type: "doubles", position: 1, result: i.even? ? "win" : "loss", set1_score: "6-4")
      line.match_line_players.create!(user: @joanne)
      line.match_line_players.create!(user: @mate)
    end
    # League-site Cup 6 rows for the same fixtures, saved by the old year
    # guess under 2027 and with the club spelled without "#".
    [ [ "4/27", "Laurel Creek #1" ], [ "5/4", "Waynesborough #3" ], [ "5/18", "Dupont CC #1" ] ].each_with_index do |(lbl, opp), i|
      mm, dd = lbl.split("/").map(&:to_i)
      @joanne.player_matches.create!(source: "witap", source_key: "c6-#{i}", league: "Inter-Club", division: "Cup 6",
                                     date_label: lbl, played_on: Date.new(2027, mm, dd), result: i.even? ? "win" : "loss",
                                     match_label: "Philadelphia Country 2 vs #{opp}", line_label: "Line 1")
    end
    # Two Cup 2 matches subbing for Philadelphia Country #1 (not on Court Report).
    [ [ "5/5", "Overbrook #1" ], [ "5/19", "Merion #1" ] ].each_with_index do |(lbl, opp), i|
      mm, dd = lbl.split("/").map(&:to_i)
      @joanne.player_matches.create!(source: "witap", source_key: "c2-#{i}", league: "Inter-Club", division: "Cup 2",
                                     date_label: lbl, played_on: Date.new(2027, mm, dd), result: "win",
                                     match_label: "Philadelphia Country #1 vs #{opp}", line_label: "Line 4")
    end

    record = PlayerRecord.new(@joanne)
    assert_equal 6, record.entries.size
    assert_equal 2, record.league_site_entries.size
    assert_equal [ 2026 ], record.by_year.keys

    sign_in(@joanne)
    get profile_path
    assert_select ".cr-playing-stat-detail", text: /of 6 matches/
    assert_select ".cr-stats-scope", text: /6 matches: 4 from scores on Court Report \+ 2 from league websites/
    assert_match(/3 of them are the same matches as Court Report scores/, response.body)
  end

  test "league-site dates are the most recent past day, never next year" do
    assert_equal Date.new(2026, 5, 4), DeltriPlayerHistory.most_recent(5, 4, today: Date.new(2026, 11, 16))
    assert_equal Date.new(2025, 12, 5), DeltriPlayerHistory.most_recent(12, 5, today: Date.new(2026, 11, 16))
  end

  test "team hero counts match-type calendar entries listed in the schedule" do
    team = TennisTeam.create!(user: @joanne, name: "Fixture Served", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: @joanne, tennis_team: team, role: "captain")
    team.team_events.create!(title: "vs Smashers", kind: "Match", event_date: Date.current + 2)
    team.team_events.create!(title: "vs Aces", kind: "Match", event_date: Date.current + 3)
    team.team_events.create!(title: "Friday hit", kind: "friendly", event_date: Date.current + 4)

    sign_in(@joanne)
    get team_path(team)
    assert_select ".cr-hero-stat-value", text: "2"
    assert_select ".cr-hero-breakdown", text: /2 to play · 1 friendly/
    assert_select ".cr-stat-card-label", text: "To play"
    assert_select ".cr-stat-card", text: /2\s*To play/
    assert_select ".cr-hero-stat-value", text: (Date.current + 2).strftime("%b %-d").upcase
    assert_select ".cr-sched-event", 3
  end
end
