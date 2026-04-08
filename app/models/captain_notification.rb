class CaptainNotification < ApplicationRecord
  belongs_to :user
  belongs_to :scheduled_match
  belongs_to :team_player

  validates :event_type, inclusion: { in: %w[confirmed unavailable custom] }

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(20) }

  def event_icon
    case event_type
    when "confirmed" then "\u2705"
    when "unavailable" then "\u274C"
    when "custom" then "\uD83D\uDCAC"
    end
  end

  def event_label
    case event_type
    when "confirmed" then "is available"
    when "unavailable" then "is unavailable"
    when "custom" then "left a note"
    end
  end
end
