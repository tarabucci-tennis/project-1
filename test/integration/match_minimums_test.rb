require "test_helper"

# Roster shows each player's matches against the league minimum:
# USTA = 2 before playoffs, Bux-Mont = 40% of the season.
class MatchMinimumsTest < ActionDispatch::IntegrationTest
  setup do
    @tara = User.create!(name: "Mins Tara", email: "mins-tara@example.com", password: "tennis-123")
    @jody = User.create!(name: "Mins Jody", email: "mins-jody@example.com")
  end

  def team(category, league)
    t = TennisTeam.create!(user: @tara, name: "Mins #{league}", league_category: category, league_name: league)
    [ @tara, @jody ].each { |u| TeamMembership.create!(user: u, tennis_team: t, role: "player") }
    t
  end

  def play(team, days_ago, players, result: "W")
    m = team.matches.create!(match_date: days_ago.days.ago, opponent: "Rival #{days_ago}", result: result)
    line = m.match_lines.create!(line_type: "doubles", position: 1, result: "W", set1_score: "6-4")
    players.each { |u| line.match_line_players.create!(user: u) }
    m
  end

  test "USTA: two matches on the team, counted from line scores" do
    t = team("USTA", "USTA Adult Tri-Level")
    play(t, 20, [ @tara ])
    play(t, 13, [ @tara, @jody ])
    t.matches.create!(match_date: 6.days.ago, opponent: "No Lines", result: "W") # team score only

    mins = MatchMinimums.for(t)
    assert mins.show?
    assert mins.for_player(@tara.id).met?
    assert_equal 1, mins.for_player(@jody.id).short
    assert_equal 1, mins.uncounted

    post session_path, params: { email: @tara.email, password: "tennis-123" }
    get team_path(t)
    assert_select ".cr-mins-note", text: /USTA playoffs: a player needs 2 matches/
    assert_select ".cr-mins-ok", text: /2 played/
    assert_select ".cr-mins-short", text: /1 of 2 · 1 to go/
  end

  test "Bux-Mont: 40% of the season, rounded up" do
    t = team("Local", "Bux-Mont")
    play(t, 30, [ @tara ])
    8.times { |i| t.matches.create!(match_date: (i + 1).days.from_now, opponent: "Later #{i}") }
    mins = MatchMinimums.for(t)
    assert_equal 9, mins.season_matches
    assert_equal 4, mins.needed # 40% of 9 = 3.6, rounds up
    assert_equal 3, mins.for_player(@tara.id).short
  end

  test "leagues without a rule on file show nothing" do
    assert_nil MatchMinimums.for(team("Local", "Del-Tri"))
  end
end
