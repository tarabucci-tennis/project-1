# Adds Baby Got Backhands' 2026 District matches, read from the team's public
# TennisRecord page. The team WON Districts (all four matches) and advanced to
# Sectionals, where they lost the final. Sectional matches are added separately
# (they aren't on TennisRecord's team page) once we have those scores from the
# captain.
#
# Team-level scores only (no per-line detail, to avoid mis-attributing close
# lines); the captain can add line scores via Enter Results. Idempotent: skips
# a district match that already exists for the same opponent, and updates the
# result/score of one already present so a corrected re-run fixes it.
class AddBabyGotBackhandsDistricts < ActiveRecord::Migration[8.1]
  MATCHES = [
    { date: "2026-07-17", opponent: "Unmatchables",    score: "3-2", result: "win" },
    { date: "2026-07-17", opponent: "Deuces Wild",     score: "4-1", result: "win" },
    { date: "2026-07-18", opponent: "Net Worth",       score: "3-2", result: "win" },
    { date: "2026-07-19", opponent: "Netchix 3.5 18+", score: "3-2", result: "win" }
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "baby got backhands").first
    return unless team

    MATCHES.each do |m|
      match = team.matches.where(playoff_level: "Districts")
                  .where("LOWER(opponent) = ?", m[:opponent].downcase).first
      if match
        match.update_columns(score_summary: m[:score], result: m[:result])
      else
        team.matches.create!(
          opponent:      m[:opponent],
          match_date:    Time.zone.parse("#{m[:date]} 09:00"),
          playoff_level: "Districts",
          score_summary: m[:score],
          result:        m[:result]
        )
      end
    end

    # They advanced to Sectionals; that tab appears once the sectional matches
    # are added. Leave playoff_level at least at Districts for now.
    team.update_column(:playoff_level, "Districts") if team.playoff_level.blank?
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
