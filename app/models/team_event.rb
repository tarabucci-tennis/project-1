class TeamEvent < ApplicationRecord
  belongs_to :tennis_team

  KINDS = %w[practice clinic friendly].freeze

  validates :title, presence: true
  validates :event_date, presence: true
  # The calendar offers Friendly and Clinic, or "Something else…" where a
  # captain types her own kind ("Lesson", "Team dinner"); that text is stored
  # in kind as typed.
  validates :kind, presence: true, length: { maximum: 30 }

  scope :upcoming, -> { where("event_date >= ?", PlayClock.today).order(event_date: :asc) }
  scope :chronological, -> { order(event_date: :asc) }

  # "Practice" was folded into "Friendly" (Oct 2026). Older practice rows are
  # left as they are in the database and simply shown as friendlies.
  # Used for colours: one of practice/clinic/friendly, else "other".
  def display_kind
    return "friendly" if kind == "practice"
    KINDS.include?(kind) ? kind : "other"
  end

  # "6:30 PM", however it was typed; nil if none.
  def time_label
    LineStartTime.normalize(start_time)
  end

  def kind_label
    case display_kind
    when "clinic"   then "Clinic"
    when "friendly" then "Friendly"
    else kind.to_s.squish
    end
  end

  # A calendar entry a captain added as a match ("Match", "Tournament"):
  # anything that isn't a friendly or a clinic.
  def match_like?
    display_kind == "other"
  end

  def playoff?
    "#{kind} #{title}".match?(/playoff/i)
  end

  # Over once its end time has passed (Eastern), not at midnight.
  def over?
    PlayClock.over?(event_date, start_time)
  end

  # "Kiss My Ace Winter vs Ball Busters (Away)" → "Away"; "… @ Smashers" → "Away".
  def side
    t = title.to_s
    return Regexp.last_match(1).capitalize if t =~ /\((home|away)\)/i || t =~ /[\s\-–·]\(?(home|away)\)?\s*\z/i
    return "Away" if t =~ /\s@\s/
    nil
  end

  # The title without "(Away)" / "- Home" at the end.
  def title_without_side
    title.to_s.sub(/\s*[\-–·]?\s*\(?\b(home|away)\b\)?\s*\z/i, "").squish
  end

  # "Over Served vs Smashers" → "Smashers"; nil when the title doesn't name an
  # opponent ("Bux-Mont Playoffs", "Team dinner").
  def opponent
    team = tennis_team&.name.to_s.squish
    t = title_without_side
    named = t.match?(/(?:\A|\s)(?:vs?\.?|versus|@)\s+\S/i)
    starts_with_team = team.present? && t.downcase.start_with?(team.downcase) && t.length > team.length
    return nil unless named || starts_with_team
    self.class.opponent_from(t, team)
  end

  # "Over Served vs Smashers" / "vs. Smashers" / "@ Smashers" → "Smashers".
  def self.opponent_from(title, team_name)
    t = title.to_s.squish
    t = t.sub(/\A#{Regexp.escape(team_name.to_s.squish)}\s*/i, "") if team_name.present?
    t = t.sub(/\A.*?(?:\A|\s|\b)(?:vs?\.?|versus|@)\s+/i, "")
    t.sub(/\A[\-–:·]\s*/, "").presence || title.to_s.squish
  end
end
