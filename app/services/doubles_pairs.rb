# Every doubles pair that has played together for a team, from the scored
# lines already in Court Report (typed results, Tenniscores sync, TennisLink
# scorecards): their record as a pair on this team, which court they usually
# play, and their record together on every Court Report team.
#
# Bux-Mont / Del-Tri / Inter-Club keep the same partners all season and only
# change for a sub, so there a pair is marked Regular or Sub. USTA partners
# change week to week, so USTA teams also get "Haven't paired yet": roster
# pairs with no history together, ranked by combined USTA rating.
class DoublesPairs
  Pair = Struct.new(:players, :wins, :losses, :courts, :last_played, :all_wins, :all_losses, keyword_init: true) do
    def together
      wins + losses
    end

    def all_together
      all_wins + all_losses
    end

    # Most-played court label and how many times there.
    def usual_court
      courts.tally.max_by { |label, n| [ n, label ] }
    end
  end
  Idea = Struct.new(:players, :combined, keyword_init: true)

  IDEAS_SHOWN = 6

  attr_reader :team

  def initialize(team)
    @team = team
  end

  # Partners stay fixed except for subs (everything but USTA).
  def fixed_partners?
    team.league_group != "USTA"
  end

  def pairs
    @pairs ||= build_pairs
  end

  # In fixed-partner leagues: a regular pairing, or a one-off with a sub.
  def regular?(pair)
    pair.together >= 3 || (scored_match_count.positive? && pair.together >= scored_match_count * 0.4)
  end

  def ideas
    return [] if fixed_partners?
    @ideas ||= begin
      played = pairs.map { |p| p.players.map(&:id).sort }.to_set
      rated = roster.select { |u| u.ntrp_rating.to_f.positive? }
      rated.combination(2)
           .reject { |a, b| played.include?([ a.id, b.id ].sort) }
           .map { |a, b| Idea.new(players: [ a, b ].sort_by { |u| -u.ntrp_rating.to_f }, combined: a.ntrp_rating.to_f + b.ntrp_rating.to_f) }
           .sort_by { |i| [ -i.combined, i.players.map(&:name).join ] }
           .first(IDEAS_SHOWN)
    end
  end

  private

  def roster
    @roster ||= team.team_memberships.active.includes(:user).map(&:user).compact
  end

  def team_lines
    @team_lines ||= MatchLine.joins(:match)
                             .where(matches: { tennis_team_id: team.id }, line_type: "doubles")
                             .where.not(result: [ nil, "" ])
                             .includes(:match, match_line_players: :user).to_a
  end

  def scored_match_count
    @scored_match_count ||= team_lines.map(&:match_id).uniq.size
  end

  def pair_key(line)
    ids = line.match_line_players.map(&:user_id)
    ids.size == 2 ? ids.sort : nil
  end

  def build_pairs
    singles = team.lineup_slot_plan.keys.count { |(type, _)| type == "singles" }
    by_pair = team_lines.group_by { |l| pair_key(l) }.except(nil)
    return [] if by_pair.empty?

    everywhere = all_team_records(by_pair.keys)
    by_pair.map do |key, lines|
      players = lines.first.match_line_players.map(&:user).sort_by { |u| u.name.to_s }
      all = everywhere[key] || { wins: 0, losses: 0 }
      Pair.new(players: players,
               wins: lines.count { |l| l.result == "win" }, losses: lines.count { |l| l.result == "loss" },
               courts: lines.map { |l| court_label(l.position - singles) },
               last_played: lines.map { |l| l.match.match_date }.max,
               all_wins: all[:wins], all_losses: all[:losses])
    end.sort_by { |p| [ -p.together, -p.wins, p.players.map(&:name).join ] }
  end

  # The same pairs' records across every Court Report team they've played on.
  def all_team_records(keys)
    ids = keys.flatten.uniq
    lines = MatchLine.where(line_type: "doubles").where.not(result: [ nil, "" ])
                     .where(id: MatchLinePlayer.where(user_id: ids).select(:match_line_id))
                     .includes(:match_line_players)
    wanted = keys.to_set
    lines.each_with_object({}) do |line, acc|
      key = pair_key(line)
      next unless key && wanted.include?(key)
      rec = (acc[key] ||= { wins: 0, losses: 0 })
      rec[:wins] += 1 if line.result == "win"
      rec[:losses] += 1 if line.result == "loss"
    end
  end

  def court_label(n)
    level = team.doubles_line_level(n) if team.tri_level?
    level ? "#{level} Doubles" : "Doubles #{n}"
  end
end
