# How many matches each rostered player has played for a team, against the
# league's minimum:
#   USTA (incl. Tri-Level): 2 matches on this team before playoffs
#     (USTA League Regulation 2.03; 3 for self-rated players, which Court
#     Report doesn't know, so the page says so).
#   Bux-Mont: at least 40% of the season's matches (Rule C.3), rounded up.
# Other leagues have no rule on file, so .for returns nil.
#
# A match counts for a player when she's on a scored line of a regular-season
# match. Matches with only a team score (no line players) can't be counted,
# and the page says how many of those there are.
class MatchMinimums
  USTA_PLAYOFF_MIN = 2
  BUX_MONT_SHARE = 0.4

  Count = Struct.new(:played, :needed, keyword_init: true) do
    def met? = played >= needed
    def short = [ needed - played, 0 ].max
  end

  attr_reader :kind, :needed, :season_matches, :uncounted

  def self.for(team)
    kind = if team.league_group == "USTA" then :usta
    elsif team.league_label.to_s.casecmp?("Bux-Mont") then :bux_mont
    end
    kind && new(team, kind)
  end

  def initialize(team, kind)
    @team = team
    @kind = kind
    regular = team.matches.reject(&:playoff?)
    @season_matches = regular.size
    @needed = kind == :usta ? USTA_PLAYOFF_MIN : (BUX_MONT_SHARE * @season_matches).ceil

    played = regular.select(&:played?)
    lines = MatchLine.where(match_id: played.map(&:id)).includes(:match_line_players).to_a
    with_players = lines.select { |l| l.scored? && l.match_line_players.any? }
    @counts = Hash.new(0)
    with_players.group_by(&:match_id).each_value do |match_lines|
      match_lines.flat_map { |l| l.match_line_players.map(&:user_id) }.uniq.each { |uid| @counts[uid] += 1 }
    end
    @uncounted = played.size - with_players.map(&:match_id).uniq.size
  end

  def for_player(user_id)
    Count.new(played: @counts[user_id], needed: @needed)
  end

  # Only worth showing once there's a season and at least one counted match.
  def show?
    @needed.positive? && @counts.any?
  end

  def rule_text
    if kind == :usta
      "USTA playoffs: a player needs #{needed} matches on this team first (3 if self-rated)."
    else
      "Bux-Mont: every player must play at least 40% of the season, #{needed} of #{season_matches} matches."
    end
  end
end
