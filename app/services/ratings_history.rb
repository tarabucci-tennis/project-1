# Everything the Ratings pages show, from two places, merged:
#   1. Scores players enter on Court Report for USTA teams (automatic — no
#      uploads needed). Our players come from the line's players; opponents
#      from the "Opponents" box.
#   2. Lines saved from TennisLink "Individual Result" uploads (optional,
#      for older matches or fuller opponent names).
# When the same line exists in both (same date, same names on one side), the
# uploaded copy wins and the Court Report copy is dropped.
class RatingsHistory
  # A Court Report-entered line, shaped like a UstaLine.
  class AppLine
    include RatedLine

    attr_reader :match_date, :league, :level, :match_type, :line_type, :winners, :losers, :score, :section

    def initialize(match_date:, league:, level:, match_type:, line_type:, winners:, losers:, score:, section: nil)
      @match_date, @league, @level, @match_type, @line_type = match_date, league, level, match_type, line_type
      @winners, @losers, @score, @section = winners, losers, score, section
    end

    def district
      nil
    end
  end

  PlayerSummary = Struct.new(:name, :wins, :losses, :last_date, keyword_init: true) do
    def lines
      wins + losses
    end
  end

  def self.lines
    uploaded = UstaLine.all.to_a
    taken = uploaded.flat_map(&:side_keys).to_set
    entered = app_lines.reject { |l| l.side_keys.any? { |k| taken.include?(k) } }
    uploaded + entered
  end

  # One player's lines from their side, newest first.
  def self.entries_for(name)
    lines.filter_map { |l| l.entry_for(name) }
         .sort_by { |e| e.match_date || Date.new(1900) }.reverse
  end

  # Every player seen, most lines first.
  def self.player_summaries(all = lines)
    by_key = {}
    all.sort_by { |l| l.match_date || Date.new(1900) }.each do |line|
      line.players.each do |nm|
        s = (by_key[nm.downcase.squish] ||= PlayerSummary.new(name: nm, wins: 0, losses: 0))
        if line.winners.include?(nm)
          s.wins += 1
        else
          s.losses += 1
        end
        s.last_date = line.match_date if line.match_date
      end
    end
    by_key.values.sort_by { |s| [ -s.lines, s.name.downcase ] }
  end

  # Tri-Level lines each have their own level; other USTA teams play one.
  def self.line_level(team, line_type, number)
    tri = line_type == "doubles" && team.doubles_line_level(number)
    return tri if tri
    team.rating.present? ? format("%.1f", team.rating) : nil
  end

  # Scored lines on USTA teams, with at least one of our players named.
  def self.app_lines
    rows = MatchLine.joins(match: :tennis_team)
                    .where(tennis_teams: { league_category: "USTA" }, result: %w[win loss])
                    .includes(match_line_players: :user, match: :tennis_team)
                    .to_a
    singles = MatchLine.where(match_id: rows.map(&:match_id).uniq, line_type: "singles").group(:match_id).count

    rows.filter_map do |ml|
      ours = ml.our_player_names
      next if ours.empty?

      won = ml.won?
      sets = [ ml.set1_score, ml.set2_score, ml.set3_score ].compact_blank.map { |s| s.to_s.delete(" ") }
      sets = sets.map { |s| s.split("-", 2).reverse.join("-") } unless won
      team = ml.match.tennis_team
      number = ml.line_type == "singles" ? ml.position : ml.position - singles.fetch(ml.match_id, 0)
      number = ml.position if number < 1

      AppLine.new(
        match_date: ml.match.match_date.to_date,
        league: [ team.league_name.presence || "USTA", team.name ].join(" · "),
        level: line_level(team, ml.line_type, number),
        match_type: "##{number} #{ml.line_type.capitalize}",
        line_type: ml.line_type,
        winners: won ? ours : ml.opponent_names,
        losers: won ? ml.opponent_names : ours,
        score: sets.join(","),
        section: team.section
      )
    end
  end
end
