# A club where Bux-Mont or Del-Tri matches are played. Editable on the
# Standings tab of those teams; used to show where each match is (Match#venue).
#
# `aliases` = how team names start, comma separated ("Frog" matches
# "Frogaritas" and "Frog Hollow Orange"). The club's own name always counts.
class Club < ApplicationRecord
  LEAGUES = %w[Bux-Mont Del-Tri].freeze

  validates :league, inclusion: { in: LEAGUES }
  validates :name, presence: true, length: { maximum: 100 },
                   uniqueness: { scope: :league, case_sensitive: false }
  validates :address, length: { maximum: 200 }
  validates :aliases, length: { maximum: 200 }

  before_validation do
    self.name = name.to_s.squish
    self.address = address.to_s.squish.presence
    self.aliases = alias_list.join(", ").presence
  end

  scope :in_league, ->(league) { where(league: league).order(:name) }

  def alias_list
    aliases.to_s.split(",").map(&:squish).reject(&:blank?).uniq
  end

  # The address as two lines for display: street, then "Town, ST 12345".
  def address_lines
    street, rest = address.to_s.split(/,\s*/, 2)
    [ street, rest ].compact_blank
  end

  def full
    [ name, address ].compact_blank.join(", ")
  end

  def maps_url
    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(full)}"
  end

  # Who may add or change a league's clubs: an admin, or a captain or
  # co-captain of any team in that league.
  def self.editable_by?(user, league)
    return false unless user
    return true if user.admin?
    TeamMembership.active.where(user: user, role: %w[captain co_captain])
                  .joins(:tennis_team).where(tennis_teams: { league_name: league }).exists?
  end
end
