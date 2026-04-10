class Match < ApplicationRecord
  belongs_to :tennis_team
  has_many :availabilities, dependent: :destroy
  has_many :match_lines, -> { order(position: :asc) }, dependent: :destroy
  has_many :match_line_players, through: :match_lines
  has_one :lineup, dependent: :destroy

  validates :match_date, presence: true

  scope :upcoming, -> { where("match_date >= ?", Time.current).order(match_date: :asc) }
  scope :past, -> { where("match_date < ?", Time.current).order(match_date: :desc) }
  scope :chronological, -> { order(match_date: :asc) }
  scope :completed, -> { where.not(result: nil) }

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

  def played?
    result.present?
  end

  def won?
    result == "win"
  end

  def lost?
    result == "loss"
  end

  def result_label
    return nil unless played?
    won? ? "W" : "L"
  end

  def lines_won
    match_lines.where(result: "win").count
  end

  def lines_lost
    match_lines.where(result: "loss").count
  end

  # Did a specific player play in this match?
  def player_played?(user)
    match_line_players.exists?(user: user)
  end
end
