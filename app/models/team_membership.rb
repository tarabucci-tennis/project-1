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
  scope :active,       -> { where(archived_season: nil) }
  scope :archived,     -> { where.not(archived_season: nil) }

  def archived?
    archived_season.present?
  end

  def captain?
    role == "captain"
  end

  def co_captain?
    role == "co_captain"
  end

  def leader?
    captain? || co_captain?
  end

  # Does this membership have the per-player W/L aggregates that
  # points-based leagues (Del-Tri, Inter-Club) show on their public
  # roster pages? Returns true when either number is set — a 0
  # counts as a real value, only nil means "unknown".
  def season_record?
    !season_wins.nil? || !season_losses.nil?
  end

  def season_record_label
    return nil unless season_record?
    "#{season_wins.to_i}-#{season_losses.to_i}"
  end

  # Sort key for the Del-Tri-style roster. Captains float to the top,
  # then players grouped by position (1 first), then alphabetical within
  # a position. Nil positions sort last.
  def deltri_sort_key
    pos = season_position.to_s.match?(/\A\d+\z/) ? season_position.to_i : Float::INFINITY
    [ captain? ? 0 : 1, pos, user.name.to_s.downcase ]
  end
end
