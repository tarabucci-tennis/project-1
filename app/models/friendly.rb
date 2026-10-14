# A casual round robin a player organizes and shares by link. Anyone with the
# link adds their name; there's no limit and no waitlist. The number of courts
# comes from the sign-ups (every 4 names = 1 court) and anyone left over
# rotates sitting out. The organizer generates set-by-set doubles lineups
# (see FriendlyLineupGenerator), can swap players, mark sets played, and
# regenerate the sets that haven't been played.
#
# (The old `courts` column is no longer used: courts are worked out from names.)
class Friendly < ApplicationRecord
  PER_COURT = FriendlyLineupGenerator::PER_COURT
  MIN_PLAYERS = PER_COURT

  belongs_to :organizer, class_name: "User"
  has_many :spots, -> { order(:created_at, :id) }, class_name: "FriendlySpot", dependent: :destroy

  serialize :lineup, coder: JSON

  validates :starts_at, presence: true
  validates :sets_count, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }

  before_create { self.token ||= SecureRandom.urlsafe_base64(9) }

  # Friendlies a user organized or has a spot in.
  scope :involving, ->(user) {
    where(organizer_id: user.id).or(where(id: FriendlySpot.where(user_id: user.id).select(:friendly_id)))
  }
  scope :upcoming, -> { where("starts_at >= ?", Time.current.beginning_of_day) }

  # Everyone signed up who is in today's rotation.
  def playing_spots
    spots.select(&:in_lineup)
  end

  def player_names
    playing_spots.map(&:name)
  end

  def courts_needed
    FriendlyLineupGenerator.courts_for(playing_spots.size)
  end

  # Players sitting out each set with the current sign-ups.
  def sitting_each_set
    courts_needed.zero? ? 0 : playing_spots.size - courts_needed * PER_COURT
  end

  # How many more names fill another court (4 - leftovers).
  def players_for_next_court
    PER_COURT - (playing_spots.size % PER_COURT)
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
