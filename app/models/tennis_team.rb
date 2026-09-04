class TennisTeam < ApplicationRecord
  belongs_to :user
  has_many :team_memberships, dependent: :destroy
  has_many :members, through: :team_memberships, source: :user
  has_many :matches, dependent: :destroy
  has_many :team_events, dependent: :destroy
  has_many :division_teams, dependent: :destroy

  LEAGUE_CATEGORIES = %w[USTA Inter-Club Local].freeze

  # The USTA playoff path a team can advance through after winning its flight.
  PLAYOFF_LEVELS = %w[Districts Sectionals Nationals].freeze

  validates :league_category, inclusion: { in: LEAGUE_CATEGORIES }

  # Has this team advanced to a playoff level (Districts / Sectionals / Nationals)?
  def in_playoffs?
    playoff_level.present?
  end

  # The next level up from where the team is now (nil if at Nationals or unset).
  def next_playoff_level
    return PLAYOFF_LEVELS.first unless in_playoffs?
    idx = PLAYOFF_LEVELS.index(playoff_level)
    idx ? PLAYOFF_LEVELS[idx + 1] : nil
  end

  before_create :generate_join_code

  scope :usta, -> { where(league_category: "USTA") }
  scope :inter_club, -> { where(league_category: "Inter-Club") }
  scope :local, -> { where(league_category: "Local") }

  # Groups teams into an ordered hash of { league label => [teams] }.
  # USTA first, then Inter-Club, then any other league alphabetically, so
  # adding a league is a matter of saving its name — no code change.
  CATEGORY_ORDER = { "USTA" => 0, "Inter-Club" => 1 }.freeze

  def self.group_by_league(teams)
    teams
      .group_by(&:league_label)
      .sort_by { |label, group|
        [ CATEGORY_ORDER.fetch(group.first.league_category, 2), label.to_s.downcase ]
      }
      .to_h
  end

  def league_display_name
    case league_category
    when "USTA"       then "USTA"
    when "Inter-Club" then "Inter-Club"
    when "Local"      then "Local Leagues"
    else league_category
    end
  end

  # The name to show the player: the real league ("Del-Tri", "Bux-Mont",
  # "USTA Middle States") when we know it, otherwise the generic category.
  # Used for the My Teams league tabs and the card sub-labels, which used to
  # hardcode "Del-Tri" for anything in the Local category.
  def league_label
    league_name.presence || league_display_name
  end

  # How this league's table is scored. Stored per team so a second local
  # league (Bux-Mont) isn't forced into Del-Tri's points layout.
  #   "points"   — Del-Tri / Inter-Club: total games won
  #   "win_loss" — Bux-Mont: W/L/T, line wins, games lost
  #   "usta"     — TennisLink layout: sets/games/percentages
  def standings_layout
    return standings_style if standings_style.present?
    %w[Local Inter-Club].include?(league_category) ? "points" : "usta"
  end

  def captain
    team_memberships.captains.first&.user
  end

  def captain?(user)
    return false unless user
    team_memberships.captains.exists?(user: user)
  end

  # Anyone allowed to set the lineup: captain or co-captain. Admin users
  # also pass this check at the controller level.
  def can_set_lineup?(user)
    return false unless user
    team_memberships.where(user: user, role: %w[captain co_captain]).exists?
  end

  def co_captains
    team_memberships.where(role: "co_captain").includes(:user).map(&:user)
  end

  def upcoming_matches
    matches.where("match_date >= ?", Time.current).order(match_date: :asc)
  end

  # Iterates the `matches` association in Ruby so eager-loaded collections
  # (see TeamsController#index `includes(:matches)`) don't trigger extra
  # queries per team card.
  def wins_count
    matches.count { |m| m.result == "win" }
  end

  def losses_count
    matches.count { |m| m.result == "loss" }
  end

  def record_label
    "#{wins_count}-#{losses_count}"
  end

  # Win percentage over decided matches (for the standings table). nil when
  # nothing has been played yet so the view can show a dash.
  def win_pct
    decided = wins_count + losses_count
    decided.zero? ? nil : (wins_count.to_f / decided * 100).round
  end

  # Recent results, oldest→newest: e.g. ["W", "L", "W"]. Iterates the
  # (eager-loaded) matches association in Ruby to avoid extra queries.
  def recent_form(limit = 5)
    matches.select { |m| m.result.present? }
           .sort_by(&:match_date)
           .last(limit)
           .map { |m| m.result == "win" ? "W" : (m.result == "tie" ? "T" : "L") }
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
