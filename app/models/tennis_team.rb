class TennisTeam < ApplicationRecord
  belongs_to :user
  has_many :team_memberships, dependent: :destroy
  has_many :members, through: :team_memberships, source: :user
  has_many :matches, dependent: :destroy
  has_many :division_teams, dependent: :destroy

  LEAGUE_CATEGORIES = %w[USTA Inter-Club Local].freeze

  validates :league_category, inclusion: { in: LEAGUE_CATEGORIES }

  scope :usta, -> { where(league_category: "USTA") }
  scope :inter_club, -> { where(league_category: "Inter-Club") }
  scope :local, -> { where(league_category: "Local") }

  def league_display_name
    case league_category
    when "USTA"       then "USTA"
    when "Inter-Club" then "Inter-Club"
    when "Local"      then "Local Leagues"
    else league_category
    end
  end

  def captain
    team_memberships.captains.first&.user
  end

  def captain?(user)
    return false unless user
    team_memberships.captains.exists?(user: user)
  end

  def upcoming_matches
    matches.where("match_date >= ?", Time.current).order(match_date: :asc)
  end

  def next_match
    upcoming_matches.first
  end

  def season_status
    return "past" if matches.any? && upcoming_matches.none?
    return "upcoming" if upcoming_matches.any?
    "scheduled"
  end
end
