require "test_helper"

# Enter Results fills W/L and the team result from the scores (Nov 17 2026).
class EasyScoreEntryTest < ActionDispatch::IntegrationTest
  test "line rules: USTA by sets, Bux-Mont by total games, others only when both agree" do
    split = [ [ 6, 0 ], [ 3, 6 ], [ 4, 6 ] ] # lost 1 set to 2, but won games 13-12
    assert_equal "loss", LineScoring.line_result(split, :sets)
    assert_equal "win", LineScoring.line_result(split, :games)
    assert_nil LineScoring.line_result(split, :either)
    assert_equal "win", LineScoring.line_result([ [ 6, 3 ], [ 6, 4 ] ], :either)
    assert_nil LineScoring.line_result([ [ 5, 5 ] ], :games) # level on games: tiebreak decides, she picks
    assert_equal "win", LineScoring.line_result([ [ 6, 4 ], [ 3, 6 ], [ 10, 7 ] ], :sets)
  end

  test "team rules: lines, then Bux-Mont games, then a tie; waits for undecided lines" do
    w = { result: "win", sets: [ [ 6, 2 ] ] }
    l = { result: "loss", sets: [ [ 2, 6 ] ] }
    assert_equal "win", LineScoring.match_result([ w, w, l ], :sets)
    level = [ { result: "win", sets: [ [ 6, 1 ] ] }, { result: "loss", sets: [ [ 4, 6 ] ] } ]
    assert_equal "win", LineScoring.match_result(level, :games)   # 10-7 on games
    assert_nil LineScoring.match_result(level, :sets)              # USTA: she picks
    assert_equal "tie", LineScoring.match_result([ w, l ], :either)
    assert_nil LineScoring.match_result([ w, { result: nil, sets: [ [ 3, 3 ] ] } ], :games)
  end

  test "saving number boxes with nothing tapped fills W/L, the team result and keeps 7-6(5)" do
    cap = User.create!(name: "Easy Cap", email: "easy-cap@example.com", password: "tennis-123")
    team = TennisTeam.create!(user: cap, name: "Easy Advantage", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: cap, tennis_team: team, role: "captain")
    match = team.matches.create!(opponent: "Orchids", match_date: 2.days.ago)
    a = match.match_lines.create!(line_type: "doubles", position: 1, set1_score: "7-6(5)")
    b = match.match_lines.create!(line_type: "doubles", position: 2)

    post session_path, params: { email: cap.email, password: "tennis-123" }
    get edit_results_team_match_path(team, match)
    assert_response :success
    assert_select "input.cr-se-box[inputmode=numeric]", 12
    assert_select "input[name=match_result][value=tie]"

    patch results_team_match_path(team, match), params: { lines: {
      a.id => { set1_ours: "7", set1_theirs: "6", set2_ours: "2", set2_theirs: "6" },  # games 9-12: loss (Bux-Mont)
      b.id => { set1_ours: "6", set1_theirs: "1", set2_ours: "5", set2_theirs: "5" }   # games 11-6: win
    } }
    assert_redirected_to team_path(team)
    assert_equal "loss", a.reload.result
    assert_equal "7-6(5)", a.set1_score
    assert_equal "2-6", a.set2_score
    assert_equal "win", b.reload.result
    # Lines 1-1, total games 20-18 → Bux-Mont team win.
    assert_equal "win", match.reload.result
    assert_equal "1-1", match.score_summary
  end

  test "what the player taps wins over the worked-out result" do
    cap = User.create!(name: "Tap Cap", email: "tap-cap@example.com", password: "tennis-123")
    team = TennisTeam.create!(user: cap, name: "Tap Aces", league_category: "USTA")
    TeamMembership.create!(user: cap, tennis_team: team, role: "captain")
    match = team.matches.create!(opponent: "Rivals", match_date: 2.days.ago)
    line = match.match_lines.create!(line_type: "singles", position: 1)
    post session_path, params: { email: cap.email, password: "tennis-123" }
    patch results_team_match_path(team, match), params: { match_result: "loss",
      lines: { line.id => { result: "loss", set1_ours: "6", set1_theirs: "0", set2_ours: "6", set2_theirs: "0" } } }
    assert_equal "loss", line.reload.result
    assert_equal "loss", match.reload.result
  end
end

class CaptainFormPeopleTest < ActionDispatch::IntegrationTest
  test "the player list is lineup first, then roster, then subs — no archived players" do
    cap = User.create!(name: "Grp Cap", email: "grp-cap@example.com", password: "tennis-123")
    starter = User.create!(name: "Zoe Starter")
    benched = User.create!(name: "Amy Bench")
    gone = User.create!(name: "Old Gone")
    sub = User.create!(name: "Sue Sub")
    team = TennisTeam.create!(user: cap, name: "Grp Aces", league_category: "USTA")
    TeamMembership.create!(user: cap, tennis_team: team, role: "captain")
    TeamMembership.create!(user: starter, tennis_team: team, role: "player")
    TeamMembership.create!(user: benched, tennis_team: team, role: "player")
    TeamMembership.create!(user: gone, tennis_team: team, role: "player", archived_season: "Spring 2026")
    team.team_subs.create!(user: sub)
    match = team.matches.create!(opponent: "Rivals", match_date: 1.day.ago)
    match.create_lineup!(published: true, published_at: 2.days.ago)
         .lineup_slots.create!(line_type: "doubles", position: 1, user: starter, confirmation: "confirmed")

    post session_path, params: { email: cap.email, password: "tennis-123" }
    get edit_results_team_match_path(team, match)
    assert_response :success
    labels = css_select("select.cr-select").first.css("optgroup").map { |g| g["label"] }
    assert_equal [ "In the lineup", "Roster", "Subs & others" ], labels
    assert_select "optgroup[label='In the lineup'] option", text: "Zoe Starter"
    assert_select "optgroup[label='Subs & others'] option", text: "Sue Sub"
    assert_select "option", text: /Old Gone/, count: 0
    assert_no_match(/Amy Bench \(\)/, response.body)
  end

  test "a line the captain changes records who entered it" do
    cap = User.create!(name: "Ent Cap", email: "ent-cap@example.com", password: "tennis-123")
    team = TennisTeam.create!(user: cap, name: "Ent Aces", league_category: "USTA")
    TeamMembership.create!(user: cap, tennis_team: team, role: "captain")
    match = team.matches.create!(opponent: "Rivals", match_date: 1.day.ago)
    line = match.match_lines.create!(line_type: "singles", position: 1)
    other = match.match_lines.create!(line_type: "doubles", position: 2, set1_score: "6-0", result: "win")
    post session_path, params: { email: cap.email, password: "tennis-123" }
    patch results_team_match_path(team, match), params: { lines: {
      line.id => { set1_ours: "6", set1_theirs: "1", set2_ours: "6", set2_theirs: "2" },
      other.id => { set1_ours: "6", set1_theirs: "0", result: "win" } } }
    assert_equal cap, line.reload.entered_by
    assert_nil other.reload.entered_by # unchanged line keeps no stamp
  end
end
