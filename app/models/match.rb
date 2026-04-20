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

  # Captains can now set home_away directly via the Edit Match form.
  # For older rows where the column is blank, fall back to the legacy
  # heuristic: "Home"/"Away" in notes, or a location that matches the
  # team's home court.
  def home?
    return home_away == "home" if home_away.present?
    return true if notes.to_s.include?("Home")
    home_slug = tennis_team.home_court.to_s.split(",").first.to_s.strip
    home_slug.present? && location.to_s.include?(home_slug)
  end

  def away?
    return home_away == "away" if home_away.present?
    return true if notes.to_s.include?("Away")
    false
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
