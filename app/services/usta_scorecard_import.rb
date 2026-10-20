# Saves a parsed TennisLink match Scorecard (UstaScorecardParser) onto one
# Court Report team's match: every line's players, opponents, set scores and
# W/L, plus the match result and USTA status. The official scorecard wins
# over anything typed in by hand for that match.
#
#   * the match  — found by date (the scorecard's date played); added if the
#                  team doesn't have one that day yet
#   * our side   — the team whose name matches ours, compared loosely
#                  ("Tri-Hards" == "Tri Hards")
#   * set scores — TennisLink writes them winner-first; Court Report stores
#                  ours-first, so they're flipped on lines we lost
#   * players    — matched to existing people by name; anyone new gets a
#                  plain account (no email) so their name can sit on the line
#
# `plan` previews without saving; `apply!` saves in one transaction.
class UstaScorecardImport
  PlannedLine = Struct.new(:label, :line_type, :position, :our_players, :their_players,
                           :won, :our_sets, :state, keyword_init: true)
  Plan = Struct.new(:match, :opponent, :home, :lines, :won, :lost, :warnings, keyword_init: true) do
    def result
      won > lost ? "win" : (won < lost ? "loss" : "tie")
    end
  end

  def initialize(team, parsed)
    @team = team
    @parsed = parsed
  end

  def plan
    @plan ||= build_plan
  end

  def ours?
    !plan.home.nil?
  end

  def apply!
    return false unless ours?

    p = plan
    ActiveRecord::Base.transaction do
      match = p.match || @team.matches.create!(
        match_date: Time.zone.local(@parsed.date.year, @parsed.date.month, @parsed.date.day, 12, 0),
        opponent: p.opponent, home_away: p.home ? "home" : "away"
      )

      p.lines.each do |pl|
        line = match.match_lines.find_or_initialize_by(position: pl.position)
        sets = pl.our_sets + [ nil, nil, nil ]
        line.update!(line_type: pl.line_type, result: pl.won.nil? ? nil : (pl.won ? "win" : "loss"),
                     set1_score: sets[0], set2_score: sets[1], set3_score: sets[2],
                     opponents: pl.their_players.join(" / ").presence)
        line.match_line_players.destroy_all
        pl.our_players.each { |name| line.match_line_players.create!(user: person(name)) }
      end

      attrs = { result: p.result, score_summary: "#{p.won}-#{p.lost}" }
      attrs[:usta_status] = @parsed.status if @parsed.status.present?
      match.update!(attrs)
    end
    RatingCalculator.recompute!
    true
  end

  private

  def build_plan
    key = UstaTeamSummaryParser.name_key(@team.name)
    home = if UstaTeamSummaryParser.name_key(@parsed.home_team) == key then true
    elsif UstaTeamSummaryParser.name_key(@parsed.visitor_team) == key then false
    end

    warnings = []
    if home.nil?
      warnings << "This scorecard is #{@parsed.home_team} vs. #{@parsed.visitor_team}, which doesn't include \"#{@team.name}\". Check you downloaded the right match."
      return Plan.new(match: nil, opponent: nil, home: nil, lines: [], won: 0, lost: 0, warnings: warnings)
    end

    singles_count = @team.lineup_slot_plan.keys.count { |(type, _)| type == "singles" }
    lines = @parsed.lines.map.with_index(1) do |l, i|
      ours, theirs = home ? [ l.home_players, l.visitor_players ] : [ l.visitor_players, l.home_players ]
      won = l.winner.nil? ? nil : (l.winner == :home) == home
      number = l.number || i
      PlannedLine.new(label: l.label, line_type: l.line_type, state: l.state,
                      position: l.line_type == "singles" ? number : number + singles_count,
                      our_players: ours, their_players: theirs, won: won,
                      # Winner-first on the scorecard; flip to ours-first when we lost.
                      our_sets: won == false ? l.sets.map { |s| s.split("-").reverse.join("-") } : l.sets)
    end

    match = find_match
    warnings << "No match on #{@parsed.date.strftime('%-m/%-d')} on the schedule yet. It will be added." if match.nil?
    Plan.new(match: match, opponent: home ? @parsed.visitor_team : @parsed.home_team, home: home,
             lines: lines, won: lines.count { |l| l.won == true }, lost: lines.count { |l| l.won == false },
             warnings: warnings)
  end

  def find_match
    @team.matches.select { |m| m.match_date.to_date == @parsed.date && m.playoff_level.blank? }
         .then { |same_day| same_day.one? ? same_day.first : same_day.detect { |m| similar_opponent?(m) } }
  end

  def similar_opponent?(match)
    opp = UstaTeamSummaryParser.name_key(plan_opponent)
    mine = UstaTeamSummaryParser.name_key(match.opponent)
    mine.present? && (mine.include?(opp) || opp.include?(mine))
  end

  def plan_opponent
    key = UstaTeamSummaryParser.name_key(@team.name)
    UstaTeamSummaryParser.name_key(@parsed.home_team) == key ? @parsed.visitor_team : @parsed.home_team
  end

  # A teammate by name if we have one, else anyone with that name, else a
  # new plain account (no email) so the line can show who played.
  def person(name)
    key = name.to_s.strip.downcase
    @team.members.detect { |u| u.name.to_s.strip.downcase == key } ||
      User.where("LOWER(name) = ?", key).first ||
      User.create!(name: name.strip)
  end
end
