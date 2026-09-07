# Adds Baby Got Backhands' 2026 District matches. TennisRecord listed all four
# as "wins", but the captain confirmed they LOST the Sunday final (7/19) to
# Netchix — TennisRecord's district schedule lists the winning team's score
# first, so a loss reads as "3-2" when it is really 2-3 against us. So: 3 pool
# wins (Unmatchables, Deuces Wild, Net Worth) and a loss in the final. The team
# did NOT advance to Sectionals, so playoff_level stays "Districts".
#
# Team-level scores only (no per-line detail, to avoid mis-attributing close
# lines); the captain can add line scores via Enter Results. Idempotent: skips
# a district match that already exists for the same opponent.
class AddBabyGotBackhandsDistricts < ActiveRecord::Migration[8.1]
  MATCHES = [
    { date: "2026-07-17", opponent: "Unmatchables",    score: "3-2", result: "win" },
    { date: "2026-07-17", opponent: "Deuces Wild",     score: "4-1", result: "win" },
    { date: "2026-07-18", opponent: "Net Worth",       score: "3-2", result: "win" },
    { date: "2026-07-19", opponent: "Netchix 3.5 18+", score: "2-3", result: "loss" } # Sunday final — lost
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "baby got backhands").first
    return unless team

    MATCHES.each do |m|
      next if team.matches.where(playoff_level: "Districts")
                  .where("LOWER(opponent) = ?", m[:opponent].downcase).exists?

      team.matches.create!(
        opponent:      m[:opponent],
        match_date:    Time.zone.parse("#{m[:date]} 09:00"),
        playoff_level: "Districts",
        score_summary: m[:score],
        result:        m[:result]
      )
    end

    team.update_column(:playoff_level, "Districts") if team.playoff_level.blank?
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
