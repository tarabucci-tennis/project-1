# One USTA line (e.g. "#1 Doubles" of TennisLink team match 1012187865),
# saved from the "Individual Result" exports players upload. Powers the
# Ratings page: every player's USTA match history, partners and opponents.
class UstaLine < ApplicationRecord
  include RatedLine

  NAME_COLUMNS = %w[winner_1 winner_2 loser_1 loser_2].freeze

  belongs_to :uploaded_by, class_name: "User", optional: true

  validates :usta_match_id, :match_type, presence: true

  # Lines a player (by name, any case) appears in.
  scope :for_player, ->(name) {
    key = name.to_s.downcase.squish
    where(NAME_COLUMNS.map { |c| "LOWER(#{c}) = :n" }.join(" OR "), n: key)
  }

  def winners
    [ winner_1, winner_2 ].compact_blank
  end

  def losers
    [ loser_1, loser_2 ].compact_blank
  end

  # Save every regular-season line in a parsed Individual Result file.
  # Lines already saved (from a teammate's upload) are left as they are.
  # Returns { added:, existing: }.
  def self.import(result, uploaded_by: nil)
    counts = { added: 0, existing: 0 }
    transaction do
      result.leagues.each do |league|
        league.matches.each do |m|
          next if m.match_id.blank? || m.match_type.blank?

          line = find_or_initialize_by(usta_match_id: m.match_id, match_type: m.match_type)
          unless line.new_record?
            counts[:existing] += 1
            next
          end

          winners = m.won ? m.our_players : m.opponents
          losers  = m.won ? m.opponents : m.our_players
          line.assign_attributes(
            match_date: m.date,
            league: league.name, section: league.section, district: league.district,
            level: m.level, line_type: m.line_type, position: m.position,
            winner_1: winners[0], winner_2: winners[1],
            loser_1: losers[0], loser_2: losers[1],
            score: m.score,
            uploaded_by: uploaded_by
          )
          line.save!
          counts[:added] += 1
        end
      end
    end
    counts
  end
end
