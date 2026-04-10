class LineupSlot < ApplicationRecord
  belongs_to :lineup
  belongs_to :user

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
