class LineupSlot < ApplicationRecord
  belongs_to :scheduled_match
  belongs_to :team_player

  validates :position, presence: true,
    inclusion: { in: %w[1S 1D 2D 3D 4D] }
  validates :team_player_id, uniqueness: { scope: [ :scheduled_match_id, :position ] }

  POSITIONS = %w[1S 1D 2D 3D 4D].freeze

  POSITION_LABELS = {
    "1S" => "Singles",
    "1D" => "1st Doubles",
    "2D" => "2nd Doubles",
    "3D" => "3rd Doubles",
    "4D" => "4th Doubles"
  }.freeze

  def self.max_players_for(position)
    position == "1S" ? 1 : 2
  end
end
