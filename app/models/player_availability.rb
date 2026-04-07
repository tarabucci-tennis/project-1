class PlayerAvailability < ApplicationRecord
  belongs_to :scheduled_match
  belongs_to :team_player

  validates :status, inclusion: { in: %w[pending confirmed unavailable custom] }
  validates :team_player_id, uniqueness: { scope: :scheduled_match_id }

  def confirmed?
    status == "confirmed"
  end

  def unavailable?
    status == "unavailable"
  end

  def custom?
    status == "custom"
  end

  def display_status
    case status
    when "confirmed" then "Confirmed"
    when "unavailable" then "Unavailable"
    when "custom" then message.presence || "Maybe"
    else "Pending"
    end
  end

  def status_icon
    case status
    when "confirmed" then "\u2705"
    when "unavailable" then "\u274C"
    when "custom" then "\uD83D\uDCAC"
    else "\u2B55"
    end
  end
end
