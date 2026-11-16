# One player's record: every line they played, from ONE definition, so every
# number on the profile page (Playing Stats, the per-league tables, the
# Overall table) counts the same thing.
#
# A "match" here = one line (court) the player played and that has a result:
#   1. line scores on a Court Report team (entered, uploaded or synced), plus
#   2. matches pulled from the league websites (Del-Tri / Bux-Mont /
#      Inter-Club player pages, PlayerMatch) — this is how matches on teams
#      that aren't on Court Report (subbing, another club's team) get in.
# A league-site match that is the SAME match as a Court Report line (same
# day, same league) is counted once, from the Court Report line.
#
# With team: given, only that team's Court Report lines count (league-site
# rows can't be tied to one team reliably).
class PlayerRecord
  Entry = Struct.new(:date, :league, :team_name, :singles, :position, :result,
                     :partners, :opponent, :opponents, :score, :source, :match_id, :player_ids,
                     keyword_init: true) do
    def won? = result == "win"
    def lost? = result == "loss"
    def year = date&.year
    def line_label = position ? "#{position}#{singles ? 'S' : 'D'}" : nil
  end

  attr_reader :user, :team

  def initialize(user, team: nil)
    @user = user
    @team = team
  end

  def entries
    @entries ||= (court_report_entries + league_site_entries).sort_by { |e| e.date || Date.new(0) }
  end

  def court_report_entries
    @court_report_entries ||= begin
      lines = MatchLine.joins(:match_line_players)
                       .where(match_line_players: { user_id: user.id })
                       .where(result: %w[win loss])
                       .includes({ match: :tennis_team }, match_line_players: :user)
                       .distinct
      lines = lines.joins(:match).where(matches: { tennis_team_id: team.id }) if team
      lines.filter_map do |line|
        match = line.match
        next unless match&.match_date && match.tennis_team

        players = line.match_line_players.map(&:user).compact
        Entry.new(
          date: match.match_date.to_date, league: match.tennis_team.league_label,
          team_name: match.tennis_team.name, singles: line.line_type == "singles",
          position: line.position, result: line.result,
          partners: players.reject { |u| u.id == user.id }.map(&:name),
          opponent: match.opponent, opponents: line.opponents, score: line.score_display, source: :court_report,
          match_id: match.id, player_ids: players.map { |u| { id: u.id, name: u.name } }
        )
      end
    end
  end

  # League-site rows not already counted from a Court Report line.
  def league_site_entries
    return [] if team

    @league_site_entries ||= begin
      taken = Hash.new(0)
      court_report_entries.each { |e| taken[self.class.dedupe_key(e.date, e.league)] += 1 }
      user.player_matches.where(result: %w[win loss]).order(:played_on).filter_map do |pm|
        key = self.class.dedupe_key(pm.played_on, pm.league)
        if taken[key].positive?
          taken[key] -= 1
          next
        end
        Entry.new(
          date: pm.played_on, league: pm.league.presence || "Other",
          team_name: [ pm.league, pm.division ].compact_blank.join(" · ").presence, singles: false,
          position: pm.line_label.to_s[/\d+/]&.to_i, result: pm.result,
          partners: [ pm.partner ].compact_blank, opponent: pm.match_label, opponents: pm.opponents,
          score: pm.score, source: :league_site, match_id: nil,
          player_ids: [ { id: user.id, name: user.name } ]
        )
      end
    end
  end

  # Ids of the league-site rows that are the same match as a Court Report
  # line, so League Match History can say which ones are counted from there.
  def duplicate_player_match_ids
    taken = Hash.new(0)
    court_report_entries.each { |e| taken[self.class.dedupe_key(e.date, e.league)] += 1 }
    user.player_matches.where(result: %w[win loss]).order(:played_on).each_with_object([]) do |pm, ids|
      key = self.class.dedupe_key(pm.played_on, pm.league)
      next unless taken[key].positive?
      taken[key] -= 1
      ids << pm.id
    end
  end

  def self.dedupe_key(date, league)
    [ date, league.to_s.downcase.squish ]
  end

  # { won:, lost:, total: } over a set of entries.
  def self.tally(list)
    won = list.count(&:won?)
    lost = list.count(&:lost?)
    { won: won, lost: lost, total: won + lost }
  end

  # Matches / won / lost per year, all leagues together.
  def by_year
    entries.group_by(&:year).compact.transform_values { |list| self.class.tally(list) }
  end

  # { league => { year => { matches:, won:, lost: } } }
  def by_league_year
    entries.group_by(&:league).transform_values do |list|
      list.group_by(&:year).transform_values do |l|
        t = self.class.tally(l)
        { matches: t[:total], won: t[:won], lost: t[:lost] }
      end
    end
  end
end
