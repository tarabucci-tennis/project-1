require "date"

# Parses a USTA TennisLink "Team Summary" export ("Send To Excel" on a team's
# Stats & Standings page). The download is really an HTML table despite the
# .xls name. It carries USTA's own published numbers, which Court Report
# stores as-is and never recalculates (USTA's points are weighted per
# position, and its games-won % excludes defaults):
#
#   * team info  — league, flight, season dates, format
#   * standings  — every team in the flight: matches, points, sets, games, %
#   * matches    — this team's matches: date, opponent, points ("23-0", our
#                  points first) and USTA's confirmation status
#   * roster     — every player with her official NTRP rating
#
# Also reads the "Match Summary by Team" report (TennisLink's other Send To
# Excel download): one row per match with home and visiting team, lines won
# by each ("Team Wins") and USTA's status. It has no standings or roster.
# Pass `team_name:` so each row can be read from our side.
#
# Plain string scanning, no gems. Nothing here touches the database.
class UstaTeamSummaryParser
  Standing = Struct.new(:name, :matches_played, :points, :sets_won, :sets_lost,
                        :games_won, :games_lost, :games_won_pct, keyword_init: true)
  TeamMatch = Struct.new(:date, :opponent, :our_points, :their_points, :status, :home, keyword_init: true) do
    def played?
      !our_points.nil?
    end

    def result
      return nil unless played?
      our_points > their_points ? "win" : (our_points < their_points ? "loss" : "tie")
    end

    def confirmed?
      status.to_s.match?(/confirmed/i)
    end
  end
  Player = Struct.new(:name, :ntrp, keyword_init: true)
  Result = Struct.new(:section, :district, :league, :flight, :season_start, :season_end, :format,
                      :captain, :co_captain, :facility, :facility_address,
                      :standings, :matches, :players, keyword_init: true) do
    def summary_file?
      standings.any? || players.any?
    end

    # A "Match Summary by Team" report: matches only.
    attr_accessor :match_summary
    alias_method :match_summary?, :match_summary
  end

  def self.parse(html, team_name: nil)
    new(html, team_name: team_name).parse
  end

  def initialize(html, team_name: nil)
    @team_name = team_name
    @rows = html.to_s.scan(/<tr[^>]*>(.*?)<\/tr>/im).map do |(row)|
      row.scan(/<t[dh][^>]*>(.*?)<\/t[dh]>/im).map { |(c)| clean(c) }
    end
  end

  def parse
    info = row_after([ "Section", "District/Area", "League" ]) || []
    staff = row_after([ "Captain", "Co-Captain", "Facility" ]) || []
    facility, facility_address = split_facility(staff[2])
    dates = @rows.flatten.join(" ").scan(%r{\d{2}/\d{2}/\d{4}})
    Result.new(
      section:      info[0],
      district:     info[1],
      captain:      person_name(staff[0]),
      co_captain:   person_name(staff[1]),
      facility:     facility,
      facility_address: facility_address,
      league:       info[2],
      flight:       info[3],
      season_start: parse_date(dates[0]),
      season_end:   parse_date(dates[1]),
      format:       @rows.flatten.join(" ")[/Format:\s*([^;]+?)(?:\s+Captain's Message|\z)/i, 1]&.strip,
      standings:    standings,
      matches:      match_summary_rows ? match_summary_matches : matches,
      players:      players
    ).tap { |r| r.match_summary = !match_summary_rows.nil? }
  end

  private

  def standings
    start = @rows.index { |r| r.first == "Team Name" && r.include?("Matches Played") }
    return [] unless start

    @rows[(start + 1)..].take_while { |r| r.size >= 8 && r[1].to_s.match?(/\A\d+\z/) }.map do |r|
      Standing.new(
        name: r[0], matches_played: r[1].to_i, points: r[2].to_i,
        sets_won: r[3].to_i, sets_lost: r[4].to_i,
        games_won: r[5].to_i, games_lost: r[6].to_i,
        games_won_pct: r[7].to_s.delete("%").to_f
      )
    end
  end

  # Rows hold two matches side by side: date, (blank), opponent, points-cell.
  def matches
    start = @rows.index { |r| r.first == "Date" && r.include?("Opponent") }
    return [] unless start

    @rows[(start + 1)..].take_while { |r| r.first.to_s.match?(%r{\A\d{1,2}/\d{1,2}/\d{4}}) }.flat_map do |r|
      r.each_slice(4).filter_map do |date, _blank, opponent, cell|
        d = parse_date(date)
        next unless d && opponent.to_s.strip != ""

        score = cell.to_s[/(\d+)\s*-\s*(\d+)/]
        ours, theirs = score&.split("-")&.map { |n| n.strip.to_i }
        status = cell.to_s.sub(/\d+\s*-\s*\d+.*\z/, "").strip
        TeamMatch.new(date: d, opponent: opponent, our_points: ours, their_points: theirs,
                      status: status.presence)
      end
    end
  end

  # Rows of the Match Summary report, or nil if this isn't one:
  # Match ID, date, time, home team, ID, visiting team, ID,
  # lines won (home, visitor), match points (home, visitor), status.
  def match_summary_rows
    return @match_summary_rows if defined?(@match_summary_rows)
    start = @rows.index { |r| r.first == "Match ID" && r.include?("Home Team") && r.include?("Visiting Team") }
    @match_summary_rows = start && @rows[(start + 1)..].select { |r| r.size >= 12 && r[0].to_s.match?(/\A\d+\z/) }
  end

  def match_summary_matches
    key = @team_name.to_s.downcase.squeeze(" ").strip
    match_summary_rows.filter_map do |r|
      home_team, visitor = r[3], r[5]
      home = [ home_team, visitor ].map { |t| t.to_s.downcase.squeeze(" ").strip }.index(key)&.zero?
      next if home.nil?

      d = parse_date(r[1])
      next unless d

      home_wins, visitor_wins = r[7].to_i, r[8].to_i
      status = dedupe_status(r[11])
      played = (home_wins + visitor_wins).positive? && !status.to_s.match?(/no team reported/i)
      ours, theirs = home ? [ home_wins, visitor_wins ] : [ visitor_wins, home_wins ]
      TeamMatch.new(date: d, opponent: home ? visitor : home_team,
                    our_points: (ours if played), their_points: (theirs if played),
                    status: status, home: home)
    end
  end

  # The report prints each status twice ("Confirmed by 48 hr rule Confirmed by 48 hr rule").
  def dedupe_status(cell)
    words = cell.to_s.split
    half = words.size / 2
    text = words.size.even? && half.positive? && words.first(half) == words.last(half) ? words.first(half) : words
    text.join(" ").strip.then { |t| t.empty? ? nil : t }
  end

  def players
    start = @rows.index { |r| r.first == "Player Name" && r.include?("NTRP") }
    return [] unless start

    @rows[(start + 1)..].take_while { |r| r.size >= 2 && r.first.to_s != "" }.flat_map do |r|
      r.each_slice(2).filter_map do |name, ntrp|
        next if name.to_s.strip.empty?
        Player.new(name: name, ntrp: (ntrp.to_s =~ /\A\d(\.\d)?\z/ ? ntrp.to_f : nil))
      end
    end
  end

  # "Jaclyn Groenen 610-555-0100 jane@x.com" -> "Jaclyn Groenen". Phone
  # numbers and emails in the file are deliberately dropped.
  def person_name(cell)
    cell.to_s.split.reject { |w| w.include?("@") || w.match?(/\d/) }.join(" ").presence
  end

  # "Bryn Mawr Racquet Club4 N WARNER AVE BRYN MAWR PA 19010" — the club name
  # and street run together in the export; split at the first digit.
  def split_facility(cell)
    m = cell.to_s.match(/\A(\D+?)\s*(\d.*)\z/)
    m ? [ m[1].strip, m[2].strip ] : [ cell.to_s.strip.presence, nil ]
  end

  def row_after(header_prefix)
    i = @rows.index { |r| r.first(header_prefix.size) == header_prefix }
    i && @rows[i + 1]
  end

  def parse_date(str)
    m = str.to_s.match(%r{(\d{1,2})/(\d{1,2})/(\d{4})})
    m && Date.new(m[3].to_i, m[1].to_i, m[2].to_i)
  rescue ArgumentError
    nil
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub("&#39;", "'")
       .gsub(/\s+/, " ").strip
  end
end
