# A score anyone with a friendly's link can enter, no sign-in needed (Tara,
# Nov 23 2026): one row per court/line with who played and the set scores.
# Each save records the typed name and time in `history`, so the organizer can
# see who entered what; the organizer can lock scores when play is over.
class FriendlyScore < ApplicationRecord
  MAX_SETS = 3
  MAX_COURT = 20

  belongs_to :friendly

  serialize :sets, coder: JSON
  serialize :history, coder: JSON

  validates :court, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_COURT },
                    uniqueness: { scope: :friendly_id }
  validates :entered_by, presence: { message: "— please type your name" }, length: { maximum: 60 }
  validates :pair_a, :pair_b, length: { maximum: 80 }
  validate :at_least_one_set

  # [[6, 4], [3, 6]]: games for pair A then pair B, completed sets only.
  def set_scores
    Array(sets)
  end

  def sets_text
    set_scores.map { |a, b| "#{a}–#{b}" }.join(", ")
  end

  def changes_log
    Array(history)
  end

  # Builds the sets from form boxes ("set1_a" => "6", ...). A set with both
  # boxes blank is skipped; one box blank or a non-number is an error.
  def assign_set_boxes(boxes)
    @bad_set = false
    self.sets = (1..MAX_SETS).filter_map do |i|
      a = boxes["set#{i}_a"].to_s.strip
      b = boxes["set#{i}_b"].to_s.strip
      next if a.empty? && b.empty?
      unless a.match?(/\A\d{1,2}\z/) && b.match?(/\A\d{1,2}\z/)
        @bad_set = true
        next
      end
      [ a.to_i, b.to_i ]
    end
  end

  def record_change!(name)
    self.history = changes_log + [ { "by" => name, "at" => Time.current.iso8601, "sets" => sets_text } ]
  end

  private

  def at_least_one_set
    if @bad_set
      errors.add(:base, "Each set needs a whole number in both boxes (or leave both blank).")
    elsif set_scores.empty?
      errors.add(:base, "Add at least one set score.")
    end
  end
end
