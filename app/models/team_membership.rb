class TeamMembership < ApplicationRecord
  belongs_to :user
  belongs_to :tennis_team

  validates :role, inclusion: { in: %w[captain co_captain player] }
  validates :notification_preference, inclusion: { in: %w[every_update count_only off] }
  validates :user_id, uniqueness: { scope: :tennis_team_id }

  scope :captains,     -> { where(role: "captain") }
  scope :co_captains,  -> { where(role: "co_captain") }
  scope :leaders,      -> { where(role: %w[captain co_captain]) }
  scope :players,      -> { where(role: "player") }

  def captain?
    role == "captain"
  end

  def co_captain?
    role == "co_captain"
  end

  def leader?
    captain? || co_captain?
  end
end
