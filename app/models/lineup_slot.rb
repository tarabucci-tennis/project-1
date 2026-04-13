class LineupSlot < ApplicationRecord
  belongs_to :lineup
  # Optional: a freshly-created lineup has empty slots until the captain
  # picks real players for each line. We rely on the unique
  # (lineup_id, user_id) index to prevent a player from being assigned
  # to the same lineup twice once a real user is set.
  belongs_to :user, optional: true

  validates :line_type, presence: true, inclusion: { in: %w[singles doubles] }
  validates :position, presence: true

  def line_label
    if line_type == "singles"
      "#{position}S"
    else
      "#{position}D"
    end
  end

  def confirmed?
    confirmation == "confirmed"
  end

  def pending?
    confirmation == "pending"
  end

  def declined?
    confirmation == "declined"
  end
end
