class TeamEvent < ApplicationRecord
  belongs_to :tennis_team

  KINDS = %w[practice clinic friendly].freeze

  validates :title, presence: true
  validates :event_date, presence: true
  # The calendar offers Friendly and Clinic, or "Something else…" where a
  # captain types her own kind ("Lesson", "Team dinner"); that text is stored
  # in kind as typed.
  validates :kind, presence: true, length: { maximum: 30 }

  scope :upcoming, -> { where("event_date >= ?", Date.current).order(event_date: :asc) }
  scope :chronological, -> { order(event_date: :asc) }

  # "Practice" was folded into "Friendly" (Oct 2026). Older practice rows are
  # left as they are in the database and simply shown as friendlies.
  # Used for colours: one of practice/clinic/friendly, else "other".
  def display_kind
    return "friendly" if kind == "practice"
    KINDS.include?(kind) ? kind : "other"
  end

  def kind_label
    case display_kind
    when "clinic"   then "Clinic"
    when "friendly" then "Friendly"
    else kind.to_s.squish
    end
  end
end
