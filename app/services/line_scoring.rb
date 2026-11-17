# Who won a line, and the team match, from the scores typed on Enter Results,
# by each league's rule (CLAUDE.md, "League Rules"):
#   USTA      — a line goes to whoever won more SETS (a match tiebreak counts
#               as the deciding set).
#   Bux-Mont  — a line goes to whoever won more TOTAL GAMES across all sets
#               (Rule B.7); the team match to whoever won more lines, a tie on
#               lines broken by total games (B.8), and a team still level gets
#               half a point each (a tie).
#   Others    — (Del-Tri, Cup, anything new) we don't have the exact rule, so
#               a line is filled in only when sets and games agree; otherwise
#               the player picks W or L.
# Returns "win" / "loss" / "tie" or nil (= can't tell, the player picks).
# app/javascript/controllers/score_entry_controller.js mirrors this so the
# page fills in as you type; the server uses it when nothing was picked.
class LineScoring
  # :sets, :games or :either for this team.
  def self.mode_for(team)
    return :sets if team.league_category == "USTA"
    return :games if team.league_label.to_s.casecmp?("Bux-Mont")
    :either
  end

  # [[ours, theirs], ...] from "6-3" strings; sets with no number are skipped.
  def self.parse_sets(strings)
    Array(strings).filter_map do |s|
      ours, theirs = s.to_s.scan(/\d+/).first(2).map(&:to_i)
      next unless ours && theirs
      [ ours, theirs ]
    end
  end

  def self.line_result(sets, mode)
    return nil if sets.empty?
    by_sets = compare(sets.count { |o, t| o > t }, sets.count { |o, t| t > o })
    by_games = compare(sets.sum(&:first), sets.sum(&:last))
    case mode
    when :sets then by_sets
    when :games then by_games
    else by_sets == by_games ? by_sets : nil
    end
  end

  # lines: [{ result:, sets: [[o, t], ...] }, ...]
  def self.match_result(lines, mode)
    decided = lines.select { |l| %w[win loss].include?(l[:result]) }
    return nil if decided.empty?
    # A line with a score but no W/L yet: wait for it.
    return nil if lines.any? { |l| l[:sets].any? && !%w[win loss].include?(l[:result]) }
    by_lines = compare(decided.count { |l| l[:result] == "win" }, decided.count { |l| l[:result] == "loss" })
    return by_lines if by_lines
    return nil if mode == :sets # USTA can't tie on lines; let the captain pick

    if mode == :games
      games = lines.flat_map { |l| l[:sets] }
      by_games = compare(games.sum(&:first), games.sum(&:last))
      return by_games if by_games
    end
    "tie"
  end

  def self.compare(a, b)
    return "win" if a > b
    return "loss" if b > a
    nil
  end
end
