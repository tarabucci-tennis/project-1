# Court Report Rating — a live, self-contained player rating computed from the
# line scores entered in Court Report. Unlike TennisRecord (which lags weeks),
# this updates the moment a result is saved.
#
# It's a margin-aware Elo on an NTRP-ish scale: every player and opponent starts
# at BASE (4.0). For each scored line, the two sides' current ratings imply an
# expected share of games; the actual share nudges each player's rating up or
# down (K per line). Beating strong opponents by a wide margin moves you most.
#
# The rating is relative to the players/opponents recorded in Court Report — it
# behaves like an official NTRP (clusters near level, strong players float up)
# but is not a portable/official number.
class RatingCalculator
  BASE = 4.0
  K = 0.035
  SPREAD = 1.0

  def self.recompute!
    new.recompute!
  end

  def recompute!
    ratings = Hash.new(BASE)
    counts  = Hash.new(0)

    scored_lines.each do |line|
      our_users = line.match_line_players.map(&:user).compact
      next if our_users.empty?
      gw, gl = games(line)
      next if (gw + gl).zero?

      our_keys = our_users.map { |u| "u:#{u.id}" }
      opp_keys = opponent_keys(line)

      ra = avg(ratings, our_keys)
      rb = avg(ratings, opp_keys)
      expected_ours = 1.0 / (1.0 + (10**((rb - ra) / SPREAD)))
      actual_ours = gw.to_f / (gw + gl)

      our_keys.each { |k| ratings[k] += K * (actual_ours - expected_ours) }
      opp_keys.each { |k| ratings[k] += K * ((1 - actual_ours) - (1 - expected_ours)) }
      our_users.each { |u| counts["u:#{u.id}"] += 1 }
    end

    persist(ratings, counts)
  end

  private

  def scored_lines
    MatchLine.where.not(result: nil)
             .includes(:match, match_line_players: :user)
             .to_a
             .sort_by { |l| [ l.match&.match_date || Time.at(0), l.position.to_i ] }
  end

  def games(line)
    gw = gl = 0
    [ line.set1_score, line.set2_score, line.set3_score ].each do |s|
      next if s.blank?
      a, b = s.split("-")
      gw += a.to_i
      gl += b.to_i
    end
    [ gw, gl ]
  end

  # Opponents are stored as a "/"-separated name string. Each distinct name is
  # its own rated entity so opponent strength informs our players' ratings.
  # A line with no opponent names is scored against an average (BASE) opponent.
  def opponent_keys(line)
    names = line.opponents.to_s.split("/").map { |n| n.strip.downcase.gsub(/\s+/, " ") }.reject(&:blank?)
    names.any? ? names.map { |n| "o:#{n}" } : [ "o:_avg_#{line.id}" ]
  end

  def avg(ratings, keys)
    keys.sum { |k| ratings[k] } / keys.size
  end

  def persist(ratings, counts)
    User.where("id IN (?)", ratings.keys.grep(/\Au:/).map { |k| k[2..].to_i }).find_each do |u|
      key = "u:#{u.id}"
      u.update_columns(
        court_report_rating: ratings[key].round(2),
        court_report_rating_lines: counts[key]
      )
    end
  end
end
