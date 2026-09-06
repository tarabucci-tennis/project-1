# Court Report Dynamic Rating — a live, self-contained player rating computed
# from the line scores entered in Court Report. Unlike TennisRecord (which lags
# weeks), this updates the moment a result is saved.
#
# HOW IT WORKS (a systematic, NTRP-style dynamic rating):
#
#   For every scored line a player was on, we compute a "match rating":
#
#       match_rating = opponent_level + margin_delta
#
#   * opponent_level — the level of the flight the match was played at. USTA
#     flights are rating-banded (a 4.0 flight means ~4.0 opponents), so the
#     flight level is a faithful, self-contained stand-in for opponent strength
#     even though opponents are recorded only as names. We take it from the
#     team's rating, falling back to the team roster's average NTRP.
#
#   * margin_delta — how the games broke. games_won / total is the share of
#     games won; 50% means you played even with the flight (delta 0), a bigger
#     share pushes you above it, a smaller share below. Scaled by SPREAD and
#     capped at ±CAP so one blowout can't dominate — mirroring how a single
#     USTA match only moves a dynamic rating so far.
#
#   A player's dynamic rating is the average of their match ratings across the
#   whole season — every game played counts. It behaves like an official NTRP
#   dynamic (clusters near the flight level; consistent winners float up, and
#   players who win up a level rate above it) but is our own number, not a
#   portable/official one.
class RatingCalculator
  SPREAD        = 1.2   # games-margin (share above/below 50%) → rating delta scale
  CAP           = 0.6   # most a single line can move you above/below the flight
  DEFAULT_LEVEL = 3.5   # used only when a match's flight level is unknown

  def self.recompute!
    new.recompute!
  end

  def recompute!
    levels = team_levels
    sums   = Hash.new(0.0)
    counts = Hash.new(0)

    scored_lines.each do |line|
      users = line.match_line_players.map(&:user).compact
      next if users.empty?

      games_won, games_lost = games(line)
      total = games_won + games_lost
      next if total.zero?

      opp_level = levels[line.match&.tennis_team_id] || DEFAULT_LEVEL
      share     = games_won.to_f / total
      delta     = ((share - 0.5) * SPREAD).clamp(-CAP, CAP)
      match_rating = opp_level + delta

      users.each do |u|
        sums["u:#{u.id}"]   += match_rating
        counts["u:#{u.id}"] += 1
      end
    end

    persist(sums, counts)
  end

  private

  # team_id => flight level. Prefer the stored flight rating; otherwise the
  # roster's average NTRP; nil if we can't tell (falls back to DEFAULT_LEVEL).
  def team_levels
    TennisTeam.includes(:members).each_with_object({}) do |team, h|
      level = team.rating&.to_f
      level = nil if level && level <= 0
      if level.nil?
        ntrps = team.members.filter_map { |m| m.ntrp_rating&.to_f }
        level = (ntrps.sum / ntrps.size) if ntrps.any?
      end
      h[team.id] = level if level
    end
  end

  def scored_lines
    MatchLine.where.not(result: nil)
             .includes(:match, match_line_players: :user)
             .to_a
  end

  def games(line)
    won = lost = 0
    [ line.set1_score, line.set2_score, line.set3_score ].each do |s|
      next if s.blank?
      a, b = s.to_s.split("-")
      won  += a.to_i
      lost += b.to_i
    end
    [ won, lost ]
  end

  def persist(sums, counts)
    ids = counts.keys.map { |k| k[2..].to_i }
    User.where(id: ids).find_each do |u|
      key = "u:#{u.id}"
      n = counts[key]
      next if n.zero?
      u.update_columns(
        court_report_rating: (sums[key] / n).round(2),
        court_report_rating_lines: n
      )
    end
  end
end
