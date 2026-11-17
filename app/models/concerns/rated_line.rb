# Shared by every kind of line the Ratings pages show — USTA lines saved from
# uploads (UstaLine) and lines entered on Court Report (RatingsHistory::AppLine).
# Includers provide winners, losers and score (winner's games first, "6-3,4-6").
module RatedLine
  # One line, seen from one player's side.
  Entry = Struct.new(:line, :won, :partner, :opponents, :set_scores, keyword_init: true) do
    delegate :match_date, :league, :level, :match_type, to: :line
  end

  # Score entries carry placeholders and notes typed where a name goes:
  # "A (Default)", "N", "Default (no opponents)", "Nancy Krouse (timed match)".
  # A note in brackets is dropped ("Nancy Krouse"); what's left must look like
  # a person (at least two letters, not "default"/"forfeit"/"TBD"/"N/A"), or
  # it's not a player at all.
  NOT_A_NAME = /\A(n\/?a|tbd|tba|unknown|none|bye)\z|default|forfeit|walkover/i

  def self.clean_name(name)
    n = name.to_s.gsub(/\([^)]*\)/, " ").squish
    return nil if n.blank? || n.match?(NOT_A_NAME) || n.delete("^A-Za-z").length < 2
    n
  end

  def self.name_key(name)
    clean_name(name)&.downcase
  end

  # Real people on this line, notes removed.
  def players
    (winners + losers).filter_map { |n| RatedLine.clean_name(n) }
  end

  # This line from `name`'s point of view, or nil if they didn't play it.
  def entry_for(name)
    key = RatedLine.name_key(name)
    return nil unless key
    won = winners.any? { |n| RatedLine.name_key(n) == key }
    lost = losers.any? { |n| RatedLine.name_key(n) == key }
    return nil unless won || lost

    side = won ? winners : losers
    Entry.new(
      line: self,
      won: won,
      partner: side.filter_map { |n| RatedLine.clean_name(n) }.reject { |n| n.downcase == key }.first,
      opponents: (won ? losers : winners).filter_map { |n| RatedLine.clean_name(n) },
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
