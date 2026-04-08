class ScheduledMatch < ApplicationRecord
  belongs_to :team
  has_many :player_availabilities, dependent: :destroy
  has_many :lineup_slots, dependent: :destroy
  has_many :match_scores, dependent: :destroy

  validates :match_date, presence: true
  validates :opponent_team, presence: true

  scope :upcoming, -> { where("match_date >= ?", Date.current).order(:match_date) }
  scope :past, -> { where("match_date < ?", Date.current).order(match_date: :desc) }
  scope :chronological, -> { order(:match_date) }

  def home?
    home_away == "home"
  end

  def available_count
    player_availabilities.where(status: "confirmed").count
  end

  def response_count
    player_availabilities.where.not(status: "pending").count
  end

  def availability_label
    "#{available_count} OF #{team.spots_needed}"
  end

  def lineup_complete?
    lineup_slots.count >= team.spots_needed
  end

  def players_for_position(position)
    lineup_slots.where(position: position).includes(:team_player).map(&:team_player)
  end
end
