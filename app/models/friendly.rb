# A casual match a player organizes and shares by link. Anyone with the link
# can claim a spot, first come first served: 4 players per court, and anyone
# past that is on the waitlist (they move up if someone drops out or the
# organizer adds a court). Any number of courts, including 0 while courts
# aren't booked yet; sign-up is always open.
class Friendly < ApplicationRecord
  PER_COURT = 4

  belongs_to :organizer, class_name: "User"
  has_many :spots, -> { order(:created_at, :id) }, class_name: "FriendlySpot", dependent: :destroy

  validates :starts_at, presence: true
  MAX_COURTS = 30
  validates :courts, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_COURTS }

  before_create { self.token ||= SecureRandom.urlsafe_base64(9) }

  # Friendlies a user organized or has a spot in.
  scope :involving, ->(user) {
    where(organizer_id: user.id).or(where(id: FriendlySpot.where(user_id: user.id).select(:friendly_id)))
  }
  scope :upcoming, -> { where("starts_at >= ?", Time.current.beginning_of_day) }

  def capacity
    courts * PER_COURT
  end

  def players
    spots.first(capacity)
  end

  def waitlist
    spots.drop(capacity)
  end

  def full?
    spots.size >= capacity
  end

  def open_spots
    [ capacity - spots.size, 0 ].max
  end

  # Enough people waiting to fill another court?
  def room_for_another_court?
    waitlist.size >= PER_COURT
  end

  # Players grouped by court: [[spot, spot, spot, spot], [...]], padded with nil.
  def courts_with_players
    filled = players
    (0...courts).map { |c| (0...PER_COURT).map { |i| filled[c * PER_COURT + i] } }
  end

  def spot_for(user)
    user && spots.detect { |s| s.user_id == user.id }
  end

  def to_param
    token
  end
end
