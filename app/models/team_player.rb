class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :user, optional: true
  has_many :player_availabilities, dependent: :destroy
  has_many :lineup_slots, dependent: :destroy
  has_many :match_scores_as_player1, class_name: "MatchScore", foreign_key: :player1_id, dependent: :nullify
  has_many :match_scores_as_player2, class_name: "MatchScore", foreign_key: :player2_id, dependent: :nullify

  validates :player_name, presence: true
  validates :player_name, uniqueness: { scope: :team_id }
  validates :role, inclusion: { in: %w[captain co-captain player] }

  scope :ordered, -> { order(:player_name) }

  def display_name
    player_name
  end

  def captain?
    role == "captain"
  end
end
