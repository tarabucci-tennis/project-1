class Match < ApplicationRecord
  belongs_to :tennis_team
  has_many :availabilities, dependent: :destroy

  validates :match_date, presence: true

  scope :upcoming, -> { where("match_date >= ?", Time.current).order(match_date: :asc) }
  scope :chronological, -> { order(match_date: :asc) }

  def availability_for(user)
    availabilities.find_by(user: user)
  end

  def availability_counts
    in_count = availabilities.where(status: "in").count
    out_count = availabilities.where(status: "out").count
    total_members = tennis_team.team_memberships.count
    no_response = total_members - in_count - out_count
    { in: in_count, out: out_count, no_response: no_response }
  end
end
