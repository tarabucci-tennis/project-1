class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :user, optional: true
  has_many :player_availabilities, dependent: :destroy
  has_many :lineup_slots, dependent: :destroy

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
