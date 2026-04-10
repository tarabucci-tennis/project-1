class MatchLine < ApplicationRecord
  belongs_to :match
  has_many :match_line_players, dependent: :destroy
  has_many :players, through: :match_line_players, source: :user

  validates :line_type, presence: true, inclusion: { in: %w[singles doubles] }
  validates :position, presence: true

  def won?
    result == "win"
  end

  def lost?
    result == "loss"
  end

  def score_display
    sets = [set1_score, set2_score, set3_score].compact.reject(&:blank?)
    sets.join(", ")
  end

  def line_label
    if line_type == "singles"
      "Singles #{position}"
    else
      "Doubles #{position}"
    end
  end
end
