# One USTA line (e.g. "#1 Doubles" of TennisLink team match 1012187865),
# saved from the "Individual Result" exports players upload. Powers the
# Ratings page: every player's USTA match history, partners and opponents.
class UstaLine < ApplicationRecord
  NAME_COLUMNS = %w[winner_1 winner_2 loser_1 loser_2].freeze

  belongs_to :uploaded_by, class_name: "User", optional: true

  validates :usta_match_id, :match_type, presence: true

  # One line, seen from one player's side.
  Entry = Struct.new(:line, :won, :partner, :opponents, :set_scores, keyword_init: true) do
    delegate :match_date, :league, :level, :match_type, :usta_match_id, to: :line
  end

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

  def players
    winners + losers
  end

  # This line from `name`'s point of view, or nil if they didn't play it.
  def entry_for(name)
    key = name.to_s.downcase.squish
    won = winners.any? { |n| n.downcase.squish == key }
    lost = losers.any? { |n| n.downcase.squish == key }
    return nil unless won || lost

    side = won ? winners : losers
    Entry.new(
      line: self,
      won: won,
      partner: side.reject { |n| n.downcase.squish == key }.first,
      opponents: won ? losers : winners,
      set_scores: sets_for(won)
    )
  end

  # "6-3, 4-6, 1-0(7)" (winner first, as USTA prints it) → per-set strings
  # with this side's games first.
  def sets_for(won)
    score.to_s.split(",").filter_map do |set|
      w, l = set.strip.match(/\A(\d{1,2})-(\d{1,2})/)&.captures
      next unless w && l
      won ? "#{w}-#{l}" : "#{l}-#{w}"
    end
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

  # Every player in the saved history with their totals, most lines first.
  PlayerSummary = Struct.new(:name, :wins, :losses, :last_date, :last_level, keyword_init: true) do
    def lines
      wins + losses
    end
  end

  def self.player_summaries
    by_key = {}
    order(:match_date).each do |line|
      line.players.each do |nm|
        s = (by_key[nm.downcase.squish] ||= PlayerSummary.new(name: nm, wins: 0, losses: 0))
        if line.winners.include?(nm)
          s.wins += 1
        else
          s.losses += 1
        end
        s.last_date = line.match_date if line.match_date
        s.last_level = line.level if line.level.present?
      end
    end
    by_key.values.sort_by { |s| [ -s.lines, s.name.downcase ] }
  end
end
