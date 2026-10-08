# Shared by every kind of line the Ratings pages show — USTA lines saved from
# uploads (UstaLine) and lines entered on Court Report (RatingsHistory::AppLine).
# Includers provide winners, losers and score (winner's games first, "6-3,4-6").
module RatedLine
  # One line, seen from one player's side.
  Entry = Struct.new(:line, :won, :partner, :opponents, :set_scores, keyword_init: true) do
    delegate :match_date, :league, :level, :match_type, to: :line
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

  # "6-3, 4-6, 1-0(7)" (winner first) → per-set strings with this side first.
  def sets_for(won)
    score.to_s.split(",").filter_map do |set|
      w, l = set.strip.match(/\A(\d{1,2})-(\d{1,2})/)&.captures
      next unless w && l
      won ? "#{w}-#{l}" : "#{l}-#{w}"
    end
  end

  # Keys that identify this line regardless of where it came from: the date
  # plus each side's names. Used to drop a Court Report entry once the same
  # line arrives from a TennisLink upload.
  def side_keys
    [ winners, losers ].reject(&:empty?).map { |side| side_key(match_date, side) }
  end

  def self.side_key(date, names)
    [ date&.to_date, names.map { |n| n.downcase.squish }.sort ]
  end

  private

  def side_key(date, names)
    RatedLine.side_key(date, names)
  end
end
