class DivisionTeam < ApplicationRecord
  belongs_to :tennis_team

  scope :ranked, -> { order(wins: :desc, losses: :asc, name: :asc) }

  def record
    "#{wins}-#{losses}"
  end

  def total_matches
    wins + losses
  end

  def win_pct
    return 0.0 if total_matches == 0
    (wins.to_f / total_matches * 100).round(1)
  end
end
