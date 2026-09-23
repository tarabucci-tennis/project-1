require "date"

# Parses a USTA TennisLink "Send To Excel" individual-results export.
#
# That download is really an HTML table (despite the .xls name). It lists one
# player's league results across every league they played, grouped by league,
# with each match's winners, losers, set score, line (match type) and level.
#
# This reads it with plain string scanning (no gems): it returns the player's
# name and, per league, the list of matches — each already turned into "our
# side vs. opponents" and win/loss from the subject player's point of view.
# Postseason ("Championship Results") is intentionally left out for now.
#
# Nothing here touches the database; callers decide what to do with the data.
class UstaResultsParser
  Match = Struct.new(
    :match_id, :date, :match_type, :position, :line_type, :level,
    :our_players, :opponents, :score, :won, :set_scores,
    keyword_init: true
  )
  League = Struct.new(:name, :section, :district, :matches, keyword_init: true)
  Result = Struct.new(:player_name, :leagues, keyword_init: true) do
    def match_count
      leagues.sum { |l| l.matches.size }
    end
  end

  def initialize(html)
    @html = html.to_s
  end

  def self.parse(html)
    new(html).parse
  end

  def parse
    body = @html.split(/rptChampionResultsForIndividual/i, 2).first.to_s
    player = clean(body[/Player Name.*?<\/tr>\s*<tr[^>]*>\s*<td[^>]*>(.*?)<\/td>/mi, 1])

    leagues = segment_leagues(body).filter_map do |seg|
      matches = extract_matches(seg[:body], player)
      next if matches.empty?
      League.new(name: seg[:name], section: seg[:section], district: seg[:district], matches: matches)
    end

    Result.new(player_name: player, leagues: leagues)
  end

  private

  # Split the document at each league-name cell (a colspan="3" value that
  # follows the Section / District header), capturing the section + district
  # that precede it.
  def segment_leagues(body)
    parts = body.split(/<td[^>]*colspan="3"[^>]*>/i)
    parts.each_with_index.filter_map do |seg, i|
      next if i.zero?
      name = clean(seg[/\A(.*?)<\/td>/mi, 1])
      next if name.empty?
      prefix = parts[i - 1]
      sec_dist = prefix.scan(/<td[^>]*class="bottom"[^>]*>(.*?)<\/td>/mi).map { |m| clean(m[0]) }.reject(&:empty?).last(2)
      { name: name, section: sec_dist[0], district: sec_dist[1], body: seg }
    end
  end

  def extract_matches(seg, player)
    starts = []
    seg.scan(/(\d{10})\s*<\/a>/m) { starts << Regexp.last_match.begin(0) }
    starts.each_with_index.map do |from, k|
      to = starts[k + 1] || seg.length
      build_match(seg[from...to], player)
    end.compact
  end

  def build_match(chunk, player)
    winners = names(chunk, "Winner")
    losers  = names(chunk, "Loser")
    return nil if winners.empty? && losers.empty?

    mtype = chunk[/#\d+\s+(?:Singles|Doubles)/]
    position = mtype.to_s[/#(\d+)/, 1].to_i
    line_type = mtype.to_s =~ /Singles/ ? "singles" : "doubles"
    won = player_in?(winners, player)
    ours = won ? winners : losers
    opps = won ? losers : winners
    score = winner_first_score(chunk)

    Match.new(
      match_id: chunk[/\d{10}/],
      date: parse_date(chunk[/\d{1,2}\/\d{1,2}\/\d{4}/]),
      match_type: normalize_space(mtype),
      position: position,
      line_type: line_type,
      level: chunk[/(\d\.\d)\s*<\/td>/, 1],
      our_players: ours,
      opponents: opps,
      score: score,
      won: won,
      set_scores: our_set_scores(score, won)
    )
  end

  # Winner / loser player names, from the cells whose id marks the side
  # (tdIndvWinner1Name / tdIndvLoser1Name, or the championship CP variants).
  def names(chunk, side)
    chunk.scan(/<td[^>]*id="[^"]*#{side}\d*Name[^"]*"[^>]*>(.*?)<\/td>/mi)
         .map { |m| clean(m[0]) }.reject(&:empty?)
  end

  # The set score as USTA prints it (winner's games first): e.g. "7-5, 6-1".
  def winner_first_score(chunk)
    chunk.scan(%r{<td[^>]*>\s*(\d{1,2}-\d{1,2}(?:\(\d+\))?(?:\s*,\s*\d{1,2}-\d{1,2}(?:\(\d+\))?)*)\s*</td>}mi)
         .map { |m| m[0].gsub(/\s+/, "") }
         .find { |sc| sc.scan(/\d{1,2}/).map(&:to_i).all? { |n| n <= 19 } }
  end

  # Re-orient the winner-first score into our-games-first per set, so it can be
  # stored the way match_lines already keep set scores ("ours-theirs").
  def our_set_scores(score, won)
    return [] if score.to_s.empty?
    score.split(",").map do |set|
      w, l = set[/\A(\d{1,2})-(\d{1,2})/, 1], set[/\A\d{1,2}-(\d{1,2})/, 1]
      next nil unless w && l
      won ? "#{w}-#{l}" : "#{l}-#{w}"
    end.compact
  end

  def player_in?(list, player)
    key = normalize(player)
    list.any? { |n| normalize(n) == key }
  end

  def parse_date(str)
    return nil if str.to_s.empty?
    Date.strptime(str, "%m/%d/%Y")
  rescue ArgumentError
    nil
  end

  def clean(str)
    normalize_space(str.to_s.gsub(/<[^>]+>/, " ")
                          .gsub(/&nbsp;/, " ").gsub(/&#39;/, "'").gsub(/&amp;/, "&"))
  end

  def normalize_space(str)
    str.to_s.gsub(/\s+/, " ").strip
  end

  def normalize(str)
    str.to_s.downcase.gsub(/\s+/, " ").strip
  end
end
