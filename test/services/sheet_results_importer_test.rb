require "test_helper"

class SheetResultsImporterTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(name: "Tara Bucci", email: "importer-test@example.com", admin: true)
    @team = @owner.tennis_teams.create!(
      name: "Kiss My Ace", league_category: "USTA", team_type: "Adult 40+",
      section: "Middle States", gender: "F", rating: 4.0, start_date: Date.new(2026, 4, 14)
    )
    %w[Tara\ Bucci Bridget\ Hallman Alison\ Vachris Vanessa\ Halloran Sarah\ Brautigan
       Lynn\ Sundblad Mary\ Marshall Christina\ Faidley Jody\ Staples].each do |name|
      u = User.find_or_create_by!(name: name)
      TeamMembership.create!(user: u, tennis_team: @team, role: "player")
    end
    @match = @team.matches.create!(
      match_date: Time.zone.local(2026, 4, 21, 10, 30), opponent: "Unmatchables", location: "Conestoga"
    )

    @rows = [
      { match_date: "2026-04-21", opponent: "Unmatchables", line: "Singles",    player_1: "Tara Bucci",       player_2: nil,               opponent_1: "Carissa McIlwain", opponent_2: nil,               score: "3-6 6-3", result: "L" },
      { match_date: "2026-04-21", opponent: "Unmatchables", line: "#1 Doubles", player_1: "Bridget Hallman",  player_2: "Alison Vachris",  opponent_1: "Lesley Coulson",   opponent_2: "Kathryn Stewart", score: "6-2 6-4", result: "L" },
      { match_date: "2026-04-21", opponent: "Unmatchables", line: "#2 Doubles", player_1: "Vanessa Halloran", player_2: "Sarah Brautigan", opponent_1: "Kim England",      opponent_2: "Christine Walker", score: "6-2 6-0", result: "W" },
      { match_date: "2026-04-21", opponent: "Unmatchables", line: "#3 Doubles", player_1: "Lynn Sundblad",    player_2: "Mary Marshall",   opponent_1: "Carolyn Carey",    opponent_2: "Carol Leslie",    score: "7-5 6-4", result: "L" },
      { match_date: "2026-04-21", opponent: "Unmatchables", line: "#4 Doubles", player_1: "Christina Faidley", player_2: "Jody Staples",   opponent_1: "Jill Cohen",       opponent_2: "Lori Miceli",     score: "7-5 6-4", result: "W" }
    ]
  end

  test "imports match result, line scores, players, and a published lineup" do
    outcome = SheetResultsImporter.new(@team).import(@rows)
    @match.reload

    # Match-level result
    assert_equal "loss", @match.result, "2 wins vs 3 losses should be a team loss"
    assert_equal "2-3", @match.score_summary

    # Lines: singles at position 1, doubles at 2..5
    assert_equal 5, @match.match_lines.count
    singles = @match.match_lines.find_by(line_type: "singles")
    assert_equal 1, singles.position
    assert_equal "3-6", singles.set1_score
    assert_equal "6-3", singles.set2_score
    assert_equal [ 2, 3, 4, 5 ], @match.match_lines.where(line_type: "doubles").order(:position).pluck(:position)

    # Players recorded on lines (1 singles + 4 doubles*2 = 9)
    assert_equal 9, @match.match_line_players.count
    assert_includes singles.players.map(&:name), "Tara Bucci"

    # Opponents string
    d2 = @match.match_lines.find_by(position: 3)
    assert_equal "Kim England / Christine Walker", d2.opponents

    # Lineup posted from the same players
    assert @match.lineup.published?, "lineup should be published"
    assert_equal 9, @match.lineup.lineup_slots.count
    assert @match.lineup.lineup_slots.all? { |s| s.confirmation == "confirmed" }
    assert_equal 1, outcome.lineups_posted
    assert_empty outcome.unmatched
  end

  test "is idempotent — re-running does not duplicate lines, players, or slots" do
    SheetResultsImporter.new(@team).import(@rows)
    SheetResultsImporter.new(@team).import(@rows)
    @match.reload

    assert_equal 5, @match.match_lines.count
    assert_equal 9, @match.match_line_players.count
    assert_equal 9, @match.lineup.lineup_slots.count
    assert_equal "2-3", @match.score_summary
  end

  test "skips matches with no scores and reports unmatched opponents" do
    blank = @rows.map { |r| r.merge(score: "", result: "") }
    outcome = SheetResultsImporter.new(@team).import(blank)
    assert_equal 0, outcome.matches_updated

    stray = [ @rows.first.merge(opponent: "Team That Isn't Scheduled") ]
    outcome2 = SheetResultsImporter.new(@team).import(stray)
    assert_equal 1, outcome2.unmatched.size
  end
end
