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
      "Singles #{display_position}"
    else
      "Doubles #{display_position}"
    end
  end

  # "1S" / "1D" / "2D" — matches the lineup preview style on team pages.
  def short_label
    "#{display_position}#{line_type == 'singles' ? 'S' : 'D'}"
  end

  private

  # USTA matches store doubles at positions 2-5 because singles
  # takes position 1 and the unique index is [match_id, position].
  # For display we want "Doubles 1" to "Doubles 4", so subtract the
  # number of singles lines. Inter-Club / Del-Tri have no singles,
  # so the offset is 0 and positions render 1:1.
  def display_position
    return position if line_type == "singles"
    singles_offset = match.match_lines.where(line_type: "singles").count
    pos = position - singles_offset
    pos < 1 ? position : pos
  end
end
