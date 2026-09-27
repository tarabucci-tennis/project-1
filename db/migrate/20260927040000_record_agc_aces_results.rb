# Records AGC Aces' first three results (USTA Tri-Level 4.5-3.5 Wednesday),
# from the team's TennisLink match schedule as of Sept 27 2026. Score is
# AGC Aces' line wins first.
#
#   9/9  vs Whitchester Tri     W 2-1  (confirmed)
#   9/16 vs Alley Cats          W 3-0  (confirmed)
#   9/23 @  The Cynwyd Ringers  W 2-1  (reported by Cynwyd, not yet confirmed)
#
# Only fills in a match whose result is still blank, so a score a captain
# has since entered or corrected is never overwritten. Line-by-line scores
# aren't known yet, so no match lines are created.
class RecordAgcAcesResults < ActiveRecord::Migration[8.1]
  RESULTS = [
    [ [ 2026, 9, 9 ],  "whitchester tri",    "win", "2-1" ],
    [ [ 2026, 9, 16 ], "alley cats",         "win", "3-0" ],
    [ [ 2026, 9, 23 ], "the cynwyd ringers", "win", "2-1" ]
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "agc aces").first
    return unless team

    RESULTS.each do |(y, m, d), opp, result, score|
      match = team.matches.where(match_date: Date.new(y, m, d).all_day)
                  .where("LOWER(opponent) = ?", opp).first
      next unless match && match.result.blank?

      match.update!(result: result, score_summary: score)
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
