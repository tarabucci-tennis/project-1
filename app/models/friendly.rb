# A casual round robin a player organizes and shares by link. Anyone with the
# link adds their name; there's no limit. Courts come from the sign-ups
# (every 4 names = 1 court). Anyone past a full court is on the waitlist,
# first come first served, until enough join to make another court. The
# organizer generates set-by-set doubles lineups (see FriendlyLineupGenerator),
# can swap players, mark sets played, and regenerate unplayed sets.
#
# (The old `courts` column is no longer used: courts are worked out from names.)
class Friendly < ApplicationRecord
  PER_COURT = FriendlyLineupGenerator::PER_COURT
  MIN_PLAYERS = PER_COURT

  belongs_to :organizer, class_name: "User"
  has_many :spots, -> { order(:created_at, :id) }, class_name: "FriendlySpot", dependent: :destroy

  serialize :lineup, coder: JSON

  validates :starts_at, presence: true
  validate :ends_after_start

  # The form asks for an end TIME only (friendlies end the same day). Blank
  # means no end time.
  attr_writer :end_time

  def end_time
    defined?(@end_time) ? @end_time : ends_at&.strftime("%H:%M")
  end

  # How long the court is booked. Most reservations are 90 minutes or
  # 2 hours, so those are one tap; "custom" uses end_time, "none" = no end.
  DURATIONS = { "90" => 90, "120" => 120 }.freeze
  attr_writer :duration

  def duration
    return @duration if defined?(@duration)
    return "none" unless ends_at && starts_at
    mins = ((ends_at - starts_at) / 60).round
    DURATIONS.key(mins) || "custom"
  end

  before_validation :apply_end_time
  validates :sets_count, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }

  before_create { self.token ||= SecureRandom.urlsafe_base64(9) }

  # Friendlies a user organized or has a spot in.
  scope :involving, ->(user) {
    where(organizer_id: user.id).or(where(id: FriendlySpot.where(user_id: user.id).select(:friendly_id)))
  }
  scope :upcoming, -> { where("starts_at >= ?", Time.current.beginning_of_day) }

  # Everyone signed up and not marked out for today, in sign-up order.
  def active_spots
    spots.select(&:in_lineup)
  end

  # Full courts only: every 4 names = 1 court.
  def courts_needed
    FriendlyLineupGenerator.courts_for(active_spots.size)
  end

  # The first 4-per-court names play; anyone past a full court waits
  # (first come, first served) until enough join to fill another court.
  def playing_spots
    active_spots.first(courts_needed * PER_COURT)
  end

  def waitlist
    active_spots.drop(courts_needed * PER_COURT)
  end

  def player_names
    playing_spots.map(&:name)
  end

  # How many more names fill the next court.
  def players_for_next_court
    PER_COURT - (active_spots.size % PER_COURT)
  end

  # "9:00 – 11:00 AM", "11:30 AM – 1:00 PM", or just "9:00 AM".
  def time_label
    start = starts_at.strftime("%-l:%M %p")
    return start unless ends_at
    finish = ends_at.strftime("%-l:%M %p")
    if starts_at.strftime("%p") == ends_at.strftime("%p")
      "#{starts_at.strftime('%-l:%M')} – #{finish}"
    else
      "#{start} – #{finish}"
    end
  end

  def done?
    starts_at < Time.current.beginning_of_day
  end

  # ── Lineup ──────────────────────────────────────────────────────────
  # lineup = { "sets" => [ { "courts" => [[a, b, c, d], ...], "sitting" => [...], "done" => bool } ] }

  def lineup_sets
    Array((lineup || {})["sets"])
  end

  def lineup?
    lineup_sets.any?
  end

  def can_generate?
    playing_spots.size >= MIN_PLAYERS
  end

  # Builds every set that hasn't been marked played. Played sets stay as they
  # are and count toward fairness (partners, opponents and sit-outs).
  def generate_lineup!(rng: Random.new)
    raise ArgumentError, "needs at least #{MIN_PLAYERS} players" unless can_generate?

    old = lineup_sets
    played = old.first(sets_count).select { |s| s["done"] }
    gen = FriendlyLineupGenerator.new(player_names, history: played, rng: rng)
    sets = (0...sets_count).map { |i| old[i]&.dig("done") ? old[i] : gen.next_set }
    update!(lineup: { "sets" => sets })
  end

  # Swap two players inside one set. Positions are "c-i" (court c, place i)
  # or "s-i" (sitting out, place i).
  def swap_players!(set_index, pos_a, pos_b)
    sets = lineup_sets.deep_dup
    set = sets[set_index.to_i]
    return false if set.nil? || set["done"]

    a = slot_ref(set, pos_a)
    b = slot_ref(set, pos_b)
    return false unless a && b

    va = a[0][a[1]]
    vb = b[0][b[1]]
    a[0][a[1]] = vb
    b[0][b[1]] = va
    update!(lineup: { "sets" => sets })
  end

  def mark_set_done!(set_index, done)
    sets = lineup_sets.deep_dup
    return false unless sets[set_index.to_i]
    sets[set_index.to_i]["done"] = done
    update!(lineup: { "sets" => sets })
  end

  # Someone dropped out and someone else took their place on the playing
  # list: put the new player into the dropped player's exact spots in every
  # unplayed set, leaving everyone else where they were. Played sets are
  # history and never change. If the numbers don't line up (e.g. a court was
  # added), nothing is swapped and the organizer is asked to regenerate.
  def sync_lineup_names!
    return unless lineup?
    playing = player_names
    changed = false
    sets = lineup_sets.deep_dup.map do |set|
      next set if set["done"]
      slots = Array(set["courts"]).flatten + Array(set["sitting"])
      gone  = slots.uniq.reject { |n| playing.include?(n) }
      fresh = playing.reject { |n| slots.include?(n) }
      next set if gone.empty? || gone.size != fresh.size

      swap = gone.zip(fresh).to_h
      set["courts"]  = Array(set["courts"]).map { |court| court.map { |n| swap.fetch(n, n) } }
      set["sitting"] = Array(set["sitting"]).map { |n| swap.fetch(n, n) }
      changed = true
      set
    end
    update!(lineup: { "sets" => sets }) if changed
  end

  # Sign-ups changed since the unplayed sets were made?
  def lineup_out_of_date?
    return false unless lineup?
    return true if lineup_sets.size != sets_count
    want = player_names.sort
    lineup_sets.reject { |s| s["done"] }.any? { |s| (Array(s["courts"]).flatten + Array(s["sitting"])).sort != want }
  end

  def spot_for(user)
    user && spots.detect { |s| s.user_id == user.id }
  end

  def to_param
    token
  end

  private

  def apply_end_time
    if defined?(@duration)
      case @duration.to_s
      when *DURATIONS.keys then return self.ends_at = starts_at && starts_at + DURATIONS[@duration.to_s].minutes
      when "none" then return self.ends_at = nil
      end
    end
    return unless defined?(@end_time)
    hh, mm = @end_time.to_s.strip.split(":").map { |x| Integer(x, 10, exception: false) }
    self.ends_at = (hh && starts_at) ? starts_at.change(hour: hh, min: mm.to_i) : nil
  end

  def ends_after_start
    return unless ends_at && starts_at
    errors.add(:base, "End time must be after the start time") if ends_at <= starts_at
  end

  def slot_ref(set, pos)
    kind, idx = pos.to_s.split("-", 2)
    idx = Integer(idx, exception: false)
    return nil if idx.nil?
    if kind == "s"
      list = set["sitting"]
    else
      court = Integer(kind, exception: false)
      list = court && set["courts"][court]
    end
    list && idx >= 0 && idx < list.size ? [ list, idx ] : nil
  end
end
