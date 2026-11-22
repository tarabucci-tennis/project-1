require "test_helper"

# Step C (Nov 17 2026): a player enters just her own line's score.
class MyLineScoreTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Line Cap", email: "line-cap@example.com", password: "tennis-123")
    @jaci = User.create!(name: "Jaci Line", email: "jaci-line@example.com", password: "tennis-123")
    @tara = User.create!(name: "Tara Line", email: "tara-line@example.com", password: "tennis-123")
    @other = User.create!(name: "Other Line", email: "other-line@example.com", password: "tennis-123")
    @mate = User.create!(name: "Mate Line", email: "mate-line@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Line Legacy", league_category: "Local", league_name: "Del-Tri", line_format: "2D")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    [ @jaci, @tara, @other, @mate ].each { |u| TeamMembership.create!(user: u, tennis_team: @team, role: "player") }
    @match = @team.matches.create!(opponent: "DVTA 3", match_date: 1.day.ago)
    lineup = @match.create_lineup!(published: true, published_at: 2.days.ago)
    # Line 1: Jaci + Tara; line 2: Other + Mate (doubles-only league).
    lineup.lineup_slots.create!(line_type: "doubles", position: 1, user: @jaci, confirmation: "confirmed")
    lineup.lineup_slots.create!(line_type: "doubles", position: 1, user: @tara, confirmation: "confirmed")
    lineup.lineup_slots.create!(line_type: "doubles", position: 2, user: @other, confirmation: "confirmed")
    lineup.lineup_slots.create!(line_type: "doubles", position: 2, user: @mate, confirmation: "confirmed")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "a player on the lineup sees the button and enters only her own line" do
    sign_in(@jaci)
    get team_match_path(@team, @match)
    assert_select "a.cr-match-scores-btn[href=?]", my_line_team_match_path(@team, @match), text: "Enter my line's score"

    get my_line_team_match_path(@team, @match)
    assert_response :success
    # Both lineup partners were filled in (the old prefill dropped the second).
    line1 = @match.match_lines.find_by(position: 1)
    assert_equal [ @jaci.id, @tara.id ].sort, line1.match_line_players.pluck(:user_id).sort
    assert_select "select#my_line_partner option[selected]", text: /Tara Line/

    patch my_line_team_match_path(@team, @match), params: { line: {
      set1_ours: "6", set1_theirs: "2", set2_ours: "6", set2_theirs: "4", partner_id: @tara.id, opponents: "A B / C D" } }
    assert_redirected_to team_match_path(@team, @match)
    line1.reload
    assert_equal "win", line1.result
    assert_equal %w[6-2 6-4], [ line1.set1_score, line1.set2_score ]
    assert_equal @jaci, line1.entered_by
    # Line 2 untouched, and the team result waits for it.
    assert_nil @match.match_lines.find_by(position: 2).result
    assert_nil @match.reload.result

    get team_match_path(@team, @match)
    assert_select ".cr-sheet-entered", text: /Entered by Jaci/
  end

  test "the team result fills in when the last line comes in, but never over a captain's" do
    sign_in(@jaci)
    get my_line_team_match_path(@team, @match)
    patch my_line_team_match_path(@team, @match), params: { line: { set1_ours: "6", set1_theirs: "2", set2_ours: "6", set2_theirs: "4", partner_id: @tara.id } }
    sign_in(@other)
    patch my_line_team_match_path(@team, @match), params: { line: { set1_ours: "6", set1_theirs: "1", set2_ours: "6", set2_theirs: "1", partner_id: @mate.id } }
    assert_equal "win", @match.reload.result
    assert_equal "2-0", @match.score_summary

    @match.update!(result: "loss") # a captain's call stands
    sign_in(@jaci)
    patch my_line_team_match_path(@team, @match), params: { line: { set1_ours: "6", set1_theirs: "0", set2_ours: "6", set2_theirs: "0", partner_id: @tara.id } }
    assert_equal "loss", @match.reload.result
  end

  test "someone not on a line can't use it" do
    bench = User.create!(name: "Bench Line", email: "bench-line@example.com", password: "tennis-123")
    TeamMembership.create!(user: bench, tennis_team: @team, role: "player")
    sign_in(bench)
    get team_match_path(@team, @match)
    assert_select "a.cr-match-scores-btn", count: 0
    get my_line_team_match_path(@team, @match)
    assert_redirected_to team_match_path(@team, @match)
    patch my_line_team_match_path(@team, @match), params: { line: { set1_ours: "6", set1_theirs: "0" } }
    assert @match.match_lines.none?(&:scored?)
  end

  test "a non-member can't reach it at all" do
    outsider = User.create!(name: "Out Line", email: "out-line@example.com", password: "tennis-123")
    sign_in(outsider)
    get my_line_team_match_path(@team, @match)
    assert_redirected_to teams_path
  end
end

class MyLineTeamResultWaitsTest < ActionDispatch::IntegrationTest
  test "one line in doesn't decide the team result when the lineup is only partly posted" do
    cap = User.create!(name: "Wait Cap", email: "wait-cap@example.com", password: "tennis-123")
    jo = User.create!(name: "Wait Jo", email: "wait-jo@example.com", password: "tennis-123")
    mate = User.create!(name: "Wait Mate", email: "wait-mate@example.com")
    team = TennisTeam.create!(user: cap, name: "Wait Legacy", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: cap, tennis_team: team, role: "captain")
    [ jo, mate ].each { |u| TeamMembership.create!(user: u, tennis_team: team, role: "player") }
    match = team.matches.create!(opponent: "Penn Oaks", match_date: 1.day.ago)
    lineup = match.create_lineup!(published: true, published_at: 2.days.ago)
    lineup.lineup_slots.create!(line_type: "doubles", position: 2, user: jo, confirmation: "confirmed")
    lineup.lineup_slots.create!(line_type: "doubles", position: 2, user: mate, confirmation: "confirmed")
    post session_path, params: { email: jo.email, password: "tennis-123" }
    get my_line_team_match_path(team, match)
    patch my_line_team_match_path(team, match), params: { line: { set1_ours: "6", set1_theirs: "3", set2_ours: "6", set2_theirs: "4", partner_id: mate.id } }
    assert_equal "win", match.match_lines.find_by(position: 2).result
    assert_nil match.reload.result
  end
end
