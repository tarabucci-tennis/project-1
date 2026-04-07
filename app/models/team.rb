class Team < ApplicationRecord
  belongs_to :captain, class_name: "User"
  has_many :team_players, dependent: :destroy
  has_many :scheduled_matches, dependent: :destroy

  validates :name, presence: true

  def roster_count
    team_players.count
  end

  def spots_needed
    9 # 1S + 4 doubles lines x 2 players
  end
end
