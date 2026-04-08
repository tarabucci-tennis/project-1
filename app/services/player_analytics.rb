class PlayerAnalytics
  attr_reader :team_player

  def initialize(team_player)
    @team_player = team_player
    @scores = MatchScore.where(
      "player1_id = ? OR player2_id = ?",
      team_player.id, team_player.id
    ).where.not(result: nil)
  end

  def total_matches
    @scores.count
  end

  def wins
    @scores.where(result: "win").count
  end

  def losses
    @scores.where(result: "loss").count
  end

  def win_percentage
    return 0.0 if total_matches.zero?
    (wins.to_f / total_matches * 100).round(1)
  end

  def singles_count
    @scores.where(position: "1S").count
  end

  def doubles_count
    @scores.where.not(position: "1S").count
  end

  def singles_percentage
    return 0.0 if total_matches.zero?
    (singles_count.to_f / total_matches * 100).round(1)
  end

  def doubles_percentage
    return 0.0 if total_matches.zero?
    (doubles_count.to_f / total_matches * 100).round(1)
  end

  def position_breakdown
    counts = @scores.group(:position).count
    total = counts.values.sum
    return {} if total.zero?
    counts.transform_values { |c| (c.to_f / total * 100).round(1) }
  end

  def partner_stats
    doubles_scores = @scores.where.not(position: "1S")
    pairings = {}

    doubles_scores.each do |score|
      partner_id = if score.player1_id == team_player.id
        score.player2_id
      else
        score.player1_id
      end
      next unless partner_id

      pairings[partner_id] ||= { wins: 0, losses: 0 }
      if score.win?
        pairings[partner_id][:wins] += 1
      else
        pairings[partner_id][:losses] += 1
      end
    end

    partners = TeamPlayer.where(id: pairings.keys).index_by(&:id)
    pairings.map do |pid, record|
      total = record[:wins] + record[:losses]
      {
        partner: partners[pid],
        wins: record[:wins],
        losses: record[:losses],
        total: total,
        win_pct: total.positive? ? (record[:wins].to_f / total * 100).round(1) : 0.0
      }
    end.sort_by { |p| -p[:win_pct] }
  end
end
