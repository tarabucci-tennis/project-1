# Who usually plays each line. For a team's played regular-season matches
# (the last 12 months before a given match), counts how often each player was
# on each line, from the line scores entered on Court Report. Set Lineup uses
# it to show "Most often here" and to fill in an empty lineup.
class UsualLineup
  # Below this many matches with line scores, there's no real "usual" yet and
  # Set Lineup falls back to last week's lineup.
  MIN_MATCHES = 3

  Usual = Struct.new(:user, :times, :of)

  attr_reader :matches_counted

  def initialize(team, before:)
    matches = team.matches.where("match_date < ? AND match_date > ?", before, before - 1.year)
                  .reject(&:playoff?).select(&:played?)
    lines = MatchLine.where(match_id: matches.map(&:id)).includes(match_line_players: :user).to_a
    lines.select! { |l| l.scored? && l.match_line_players.any? }
    @matches_counted = lines.map(&:match_id).uniq.size

    counts = Hash.new { |h, k| h[k] = Hash.new(0) }
    users = {}
    played = Hash.new(0)
    lines.group_by(&:match_id).each_value do |match_lines|
      # USTA stores doubles after the singles lines (see MatchLine#display_position).
      singles = match_lines.count { |l| l.line_type == "singles" }
      match_lines.each do |l|
        pos = l.line_type == "singles" ? l.position : l.position - singles
        pos = l.position if pos < 1
        key = [ l.line_type, pos ]
        played[key] += 1
        l.match_line_players.each do |mlp|
          next unless mlp.user
          users[mlp.user_id] = mlp.user
          counts[key][mlp.user_id] += 1
        end
      end
    end
    @lines = counts.to_h do |key, per_user|
      list = per_user.map { |uid, n| Usual.new(users[uid], n, played[key]) }
      [ key, list.sort_by { |u| [ -u.times, u.user.name.to_s.downcase ] } ]
    end
  end

  def enough?
    @matches_counted >= MIN_MATCHES
  end

  # Players most often on this line, most first ([Usual]).
  def for_line(key)
    @lines[key] || []
  end

  # Fill an empty lineup: { line key => number of spots } becomes
  # { line key => [user ids] }. The most-played (player, line) pairs are placed
  # first, each player on one line only. Only ids in `allowed` are used (the
  # current roster, minus anyone who said they can't play).
  def suggest(spots, allowed)
    order = spots.keys
    picks = Hash.new { |h, k| h[k] = [] }
    used = Set.new
    candidates = @lines.flat_map { |key, list| list.map { |u| [ key, u ] } }
                       .select { |key, u| spots.key?(key) && allowed.include?(u.user.id) }
                       .sort_by { |key, u| [ -u.times, order.index(key), u.user.name.to_s.downcase ] }
    candidates.each do |key, u|
      next if used.include?(u.user.id) || picks[key].size >= spots[key]
      picks[key] << u.user.id
      used << u.user.id
    end
    picks
  end
end
