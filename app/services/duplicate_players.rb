# People who may be the same player entered twice (league sites spell names
# differently: "Kerry McDuffle" / "Kerry McDuffie", "Jaci Gronen" /
# "Jaclyn Groenen"). Only looks; nothing is changed. Admin-only, shown at the
# top of Site members.
#
# A pair is listed when:
#   - the names are the same once case, spaces and punctuation are ignored;
#   - the first names start alike and the last names match or are one letter
#     apart (Jaci Gronen / Jaclyn Groenen); or
#   - same first name and last names (5+ letters) one or two letters apart
#     (McDuffle / McDuffie).
class DuplicatePlayers
  Pair = Struct.new(:a, :b, :reason)

  def self.find
    new.pairs
  end

  def pairs
    users = User.includes(:member_teams).where.not(name: [ nil, "" ]).to_a
    keys = users.to_h { |u| [ u.id, key(u.name) ] }
    found = []
    users.combination(2) do |a, b|
      reason = reason_for(keys[a.id], keys[b.id])
      found << Pair.new(*[ a, b ].sort_by(&:id), reason) if reason
    end
    found.sort_by { |p| [ REASONS.index(p.reason), p.a.name.downcase ] }
  end

  REASONS = [ "Same name", "Similar name" ].freeze

  private

  def key(name)
    name.to_s.downcase.unicode_normalize(:nfkd).gsub(/[^a-z\s]/, "").split
  end

  def reason_for(x, y)
    return nil if x.empty? || y.empty?
    return "Same name" if x.join == y.join
    return nil if x.size < 2 || y.size < 2
    first_x, last_x = x.first, x.last
    first_y, last_y = y.first, y.last
    long_last = [ last_x.size, last_y.size ].min >= 5
    # Jaci Gronen / Jaclyn Groenen: first names start alike, last names match
    # or are one letter apart.
    if first_x.size >= 3 && first_y.size >= 3 && first_x[0, 3] == first_y[0, 3] &&
       (last_x == last_y || (long_last && distance(last_x, last_y) <= 1))
      return "Similar name"
    end
    # Kerry McDuffle / Kerry McDuffie: same first name, last names one or two
    # letters apart. Short last names (Lee / He) are too likely to be two people.
    return "Similar name" if first_x == first_y && long_last && distance(last_x, last_y) <= 2
    nil
  end

  # Edit distance (letters added, removed or changed), stopping early past 2.
  def distance(a, b)
    prev = (0..b.size).to_a
    a.each_char.with_index(1) do |ca, i|
      cur = [ i ]
      b.each_char.with_index(1) do |cb, j|
        cur << [ prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca == cb ? 0 : 1) ].min
      end
      return 3 if cur.min > 2
      prev = cur
    end
    prev.last
  end
end
