# Builds fair doubles rounds ("sets") for a social round robin.
#
#   gen = FriendlyLineupGenerator.new(names, history: played_sets)
#   gen.next_set # => { "courts" => [[a, b, c, d], ...], "sitting" => [...], "done" => false }
#
# A court is [a, b, c, d] meaning "a + b vs c + d". Courts = players / 4
# (rounded down); everyone else sits that set.
#
# Fairness, in priority order:
#   1. Sit-outs: whoever has sat least sits next (missing a set because you
#      weren't there yet counts as sitting), so nobody sits twice before
#      everyone has sat once. Ties go to whoever sat longest ago.
#   2. New partners every set whenever possible.
#   3. New opponents where possible.
class FriendlyLineupGenerator
  PER_COURT = 4
  TRIES = 60
  PARTNER_COST = 100
  OPPONENT_COST = 10

  def self.courts_for(player_count)
    player_count.to_i / PER_COURT
  end

  def initialize(names, history: [], rng: Random.new)
    @names = names.uniq
    @rng = rng
    @partners = Hash.new(0)
    @opponents = Hash.new(0)
    @sat = Hash.new(0)
    @last_sat = Hash.new(-1)
    @round = 0
    history.each { |set| record(set) }
  end

  def next_set
    courts = self.class.courts_for(@names.size)
    raise ArgumentError, "needs at least #{PER_COURT} players" if courts < 1

    sitting = pick_sitters(@names.size - courts * PER_COURT)
    playing = @names - sitting
    set = { "courts" => best_courts(playing), "sitting" => sitting, "done" => false }
    record(set)
    set
  end

  private

  def record(set)
    courts = Array(set["courts"])
    on_court = courts.flatten
    @names.each do |n|
      next if on_court.include?(n)
      @sat[n] += 1
      @last_sat[n] = @round
    end
    courts.each do |a, b, c, d|
      @partners[key(a, b)] += 1
      @partners[key(c, d)] += 1
      [ a, b ].each { |x| [ c, d ].each { |y| @opponents[key(x, y)] += 1 } }
    end
    @round += 1
  end

  def pick_sitters(count)
    return [] if count <= 0
    @names.sort_by { |n| [ @sat[n], @last_sat[n], @rng.rand ] }.first(count)
  end

  def best_courts(playing)
    best = nil
    best_cost = nil
    TRIES.times do
      groups = playing.shuffle(random: @rng).each_slice(PER_COURT).map { |g| best_pairing(g) }
      groups = improve(groups)
      cost = groups.sum { |g| court_cost(g) }
      best, best_cost = groups, cost if best_cost.nil? || cost < best_cost
      break if best_cost.zero?
    end
    best
  end

  # The best of the three ways to split four players into two pairs.
  def best_pairing(group)
    a, b, c, d = group
    [ [ a, b, c, d ], [ a, c, b, d ], [ a, d, b, c ] ].shuffle(random: @rng).min_by { |g| court_cost(g) }
  end

  # Swap players between courts while that lowers the total cost.
  def improve(groups)
    loop do
      improved = false
      groups.each_index do |i|
        ((i + 1)...groups.size).each do |j|
          before = court_cost(groups[i]) + court_cost(groups[j])
          groups[i].each do |x|
            groups[j].each do |y|
              gi = best_pairing(groups[i].map { |p| p == x ? y : p })
              gj = best_pairing(groups[j].map { |p| p == y ? x : p })
              next unless court_cost(gi) + court_cost(gj) < before
              groups[i] = gi
              groups[j] = gj
              improved = true
              break
            end
            break if improved
          end
        end
      end
      break unless improved
    end
    groups
  end

  def court_cost((a, b, c, d))
    PARTNER_COST * (@partners[key(a, b)] + @partners[key(c, d)]) +
      OPPONENT_COST * [ a, b ].sum { |x| [ c, d ].sum { |y| @opponents[key(x, y)] } }
  end

  def key(x, y)
    x < y ? [ x, y ] : [ y, x ]
  end
end
