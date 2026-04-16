class TeamEvent < ApplicationRecord
  belongs_to :tennis_team

  KINDS = %w[practice clinic friendly].freeze

  validates :title, presence: true
  validates :event_date, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :upcoming, -> { where("event_date >= ?", Date.current).order(event_date: :asc) }
  scope :chronological, -> { order(event_date: :asc) }

  def kind_label
    case kind
    when "practice" then "Practice"
    when "clinic"   then "Clinic"
    when "friendly" then "Friendly"
    else kind.to_s.humanize
    end
  end
end
