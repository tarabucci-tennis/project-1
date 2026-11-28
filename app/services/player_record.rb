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

    @league_site_entries ||= paired_league_site_rows[:kept].map do |pm, date|
      Entry.new(
        date: date, league: pm.league.presence || "Other",
        team_name: [ pm.league, pm.division ].compact_blank.join(" · ").presence, singles: false,
        position: pm.line_label.to_s[/\d+/]&.to_i, result: pm.result,
        partners: [ pm.partner ].compact_blank, opponent: pm.match_label, opponents: pm.opponents,
        score: pm.score, source: :league_site, match_id: nil,
        player_ids: [ { id: user.id, name: user.name } ]
      )
    end
  end

  # Ids of the league-site rows that are the same match as a Court Report
  # line, so League Match History can say which ones are counted from there.
  def duplicate_player_match_ids
    paired_league_site_rows[:duplicate_ids]
  end

  # Pairs each league-site row with the Court Report line for the same
  # FIXTURE: same day, and a match label ("Philadelphia Country #2 vs
  # Laurel Creek #1") naming that line's team or opponent (same league when
  # the row has no label).
  # Each Court Report line can absorb one league-site row.
  def paired_league_site_rows
    @paired_league_site_rows ||= begin
      open_lines = court_report_entries.dup
      kept = []
      duplicate_ids = []
      user.player_matches.where(result: %w[win loss]).order(:played_on, :id).each do |pm|
        date = self.class.played_date(pm)
        twin = open_lines.index { |e| self.class.same_fixture?(e, pm, date) }
        if twin
          open_lines.delete_at(twin)
          duplicate_ids << pm.id
        else
          kept << [ pm, date ]
        end
      end
      { kept: kept, duplicate_ids: duplicate_ids }
    end
  end

  # A played match is never in the future: rows saved by the old year guess
  # (spring Inter-Club filed under next year) are read a year earlier.
  def self.played_date(pm)
    date = pm.played_on
    return nil unless date
    date > PlayClock.today ? date.prev_year : date
  end

  def self.same_fixture?(entry, pm, date)
    return false unless entry.date && date && entry.date == date

    label = norm(pm.match_label)
    # No fixture label on the row: fall back to same day + same league.
    return norm(entry.league) == norm(pm.league) if label.blank?

    [ entry.team_name, entry.opponent ].any? { |n| (k = norm(n)).present? && label.include?(k) }
  end

  # "Philadelphia Country #2" and "Philadelphia Country 2" compare equal.
  def self.norm(str)
    str.to_s.downcase.gsub(/[^a-z0-9]+/, "")
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
