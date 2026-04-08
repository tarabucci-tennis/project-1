class MatchScore < ApplicationRecord
  belongs_to :scheduled_match
  belongs_to :player1, class_name: "TeamPlayer", optional: true
  belongs_to :player2, class_name: "TeamPlayer", optional: true

  validates :position, presence: true,
    inclusion: { in: LineupSlot::POSITIONS }
  validates :position, uniqueness: { scope: :scheduled_match_id }
  validates :result, inclusion: { in: %w[win loss] }, allow_nil: true

  def singles?
    position == "1S"
  end

  def doubles?
    !singles?
  end

  def players
    [player1, player2].compact
  end

  def set_scores
    [set1_score, set2_score, set3_score].compact.reject(&:blank?)
  end

  def set_scores_display
    set_scores.join(", ")
  end

  def win?
    result == "win"
  end

  def loss?
    result == "loss"
  end
end
