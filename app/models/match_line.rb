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
    sets = [ set1_score, set2_score, set3_score ].compact.reject(&:blank?)
    sets.join(", ")
  end

  def line_label
    if line_type == "singles"
      "Singles #{position}"
    else
      # USTA matches store doubles at positions 2-5 because singles
      # takes position 1 and the unique index is [match_id, position].
      # For the Enter Results display we want "Doubles 1" to "Doubles 4",
      # so subtract the number of singles lines in this match.
      # Inter-Club / Del-Tri matches have no singles, so the subtract
      # is 0 and positions render 1:1.
      singles_offset = match.match_lines.where(line_type: "singles").count
      display_position = position - singles_offset
      display_position = position if display_position < 1  # safety fallback
      "Doubles #{display_position}"
    end
  end
end
