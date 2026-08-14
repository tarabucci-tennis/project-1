class SetKissMyAceToDistricts < ActiveRecord::Migration[8.1]
  # Kiss My Ace advanced to Districts, so flag it — this makes the "🏆 Districts"
  # segment appear next to Results (and shows the playoff banner). Defensive so
  # it can never break a deploy.
  def up
    TennisTeam.reset_column_information
    TennisTeam.where("LOWER(name) = ?", "kiss my ace").update_all(playoff_level: "Districts")
  rescue StandardError => e
    say "Skipped setting Kiss My Ace playoff level: #{e.message}"
  end

  def down
    TennisTeam.where("LOWER(name) = ?", "kiss my ace").update_all(playoff_level: nil)
  rescue StandardError
    nil
  end
end
