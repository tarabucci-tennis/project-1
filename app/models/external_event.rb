class ExternalEvent < ApplicationRecord
  belongs_to :user

  scope :chronological, -> { order(:starts_at) }
  scope :upcoming, -> { where("starts_at >= ?", Time.current.beginning_of_day).order(:starts_at) }

  # The calendar day this event falls on, in the app's time zone.
  def on_date
    starts_at&.in_time_zone&.to_date
  end

  def time_label
    return nil if all_day || starts_at.blank?
    starts_at.in_time_zone.strftime("%-l:%M %p").sub(":00", "")
  end
end
