class TennisTeam < ApplicationRecord
  belongs_to :user
  has_many :team_memberships, dependent: :destroy
  has_many :members, through: :team_memberships, source: :user
  has_many :matches, dependent: :destroy

  def captains
    members.merge(TeamMembership.captains)
  end

  def captain?(user)
    team_memberships.captains.exists?(user: user)
  end
end
