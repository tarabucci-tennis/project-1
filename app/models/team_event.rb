class TeamEvent < ApplicationRecord
  belongs_to :tennis_team

  KINDS = %w[practice clinic friendly].freeze

  validates :title, presence: true
  validates :event_date, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :upcoming, -> { where("event_date >= ?", Date.current).order(event_date: :asc) }
  scope :chronological, -> { order(event_date: :asc) }

  # "Practice" was folded into "Friendly" (Oct 2026). Older practice rows are
  # left as they are in the database and simply shown as friendlies.
  def display_kind
    kind == "practice" ? "friendly" : kind
  end

  def kind_label
    case display_kind
    when "clinic"   then "Clinic"
    when "friendly" then "Friendly"
    else kind.to_s.humanize
    end
  end
end
