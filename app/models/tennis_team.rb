class TennisTeam < ApplicationRecord
  belongs_to :user
  has_many :team_memberships, dependent: :destroy
  has_many :members, through: :team_memberships, source: :user
  has_many :matches, dependent: :destroy
  has_many :division_teams, dependent: :destroy

  LEAGUE_CATEGORIES = %w[USTA Inter-Club Local].freeze

  validates :league_category, inclusion: { in: LEAGUE_CATEGORIES }

  before_create :generate_join_code

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

  def ensure_join_code!
    generate_join_code && save! if join_code.blank?
    join_code
  end

  # ── Lineup format (tells the Set Lineup form how many slots to show) ──
  #
  # USTA format: 1 singles line + 4 doubles lines = 5 lines, 9 player slots
  #   1S(1) + 1D(2) + 2D(2) + 3D(2) + 4D(2)
  #
  # Inter-Club (Cup) and Del-Tri (Local): 6 doubles lines, no singles
  #   1D(2) + 2D(2) + 3D(2) + 4D(2) + 5D(2) + 6D(2) = 12 player slots
  #
  # Returns an ordered hash of [line_type, position] => target_slot_count
  # that lineups_controller#ensure_default_slots uses to top up the slots
  # on a lineup, and that lineups/edit.html.erb iterates over to render
  # the form.
  def lineup_slot_plan
    case league_category
    when "Inter-Club", "Local"
      # 6 doubles, no singles
      plan = {}
      (1..6).each { |p| plan[[ "doubles", p ]] = 2 }
      plan
    else
      # USTA: 1 singles + 4 doubles
      {
        [ "singles", 1 ] => 1,
        [ "doubles", 1 ] => 2,
        [ "doubles", 2 ] => 2,
        [ "doubles", 3 ] => 2,
        [ "doubles", 4 ] => 2
      }
    end
  end

  # Does this team's league include a singles line?
  def has_singles_line?
    lineup_slot_plan.keys.any? { |(line_type, _)| line_type == "singles" }
  end

  # How many doubles lines does this team's league use? (4 or 6)
  def doubles_line_count
    lineup_slot_plan.keys.count { |(line_type, _)| line_type == "doubles" }
  end

  private

  def generate_join_code
    slug = name.to_s.parameterize
    self.join_code = "#{slug}-#{SecureRandom.hex(4)}"
  end
end
