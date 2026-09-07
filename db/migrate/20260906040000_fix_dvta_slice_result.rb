# Corrects the Kiss My Ace vs DVTA Slice district match. The automated
# TennisRecord read flipped the 1D line (Alison Vachris / Tara Bucci), which
# they actually WON. With 1D corrected the match is a 3-2 win (1D, 3D, 4D) —
# matching the official team score — not the 2-3 loss it was mistakenly set to.
class FixDvtaSliceResult < ActiveRecord::Migration[8.1]
  def up
    team = TennisTeam.where("LOWER(name) = ?", "kiss my ace").first
    return unless team

    match = team.matches
                .where(playoff_level: "Districts")
                .where("LOWER(opponent) = ?", "dvta slice")
                .first
    return unless match

    # Overall result: 3-2 win.
    match.update_columns(result: "win", score_summary: "3-2")

    # 1D is position 2 in the USTA line ordering (1S=1, 1D=2, ...).
    line = match.match_lines.find_by(position: 2)
    line&.update_columns(set1_score: "6-3", set2_score: "6-3", set3_score: nil, result: "win")
  end

  def down
    # Data correction — no automatic rollback.
  end
end
