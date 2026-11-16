# Pairs of person records that are probably the same human, for the admin
# "Possible duplicates" page:
#   - the same name ignoring case, spacing and accents ("JoAnne" / "Joanne",
#     two "Sarah Dougherty" rows), or
#   - the same first (or last) name with the other one or two letters apart
#     ("Kriste" / "Kristen", "McDuffle" / "McDuffie").
# Only suggestions: nothing merges until the admin taps Merge.
class DuplicatePeople
  Pair = Struct.new(:a, :b, :reason, keyword_init: true)

  def self.key(name)
    name.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z\s'-]/, " ").squish
  end

  def self.close?(x, y)
    return false if x.blank? || y.blank?
    return true if x == y
    return true if x.length >= 4 && y.length >= 4 && (x.start_with?(y) || y.start_with?(x)) && (x.length - y.length).abs <= 2
    x.length >= 4 && levenshtein(x, y) <= (x.length >= 7 ? 2 : 1)
  end

  def self.levenshtein(a, b)
    prev = (0..b.length).to_a
    a.each_char.with_index(1) do |ca, i|
      cur = [ i ]
      b.each_char.with_index(1) do |cb, j|
        cur << [ prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca == cb ? 0 : 1) ].min
      end
      prev = cur
    end
    prev.last
  end

  def self.pairs(users = User.where.not(name: [ nil, "" ]).to_a)
    entries = users.map { |u| [ u, key(u.name).split ] }.reject { |_, parts| parts.size < 2 }
    found = []
    entries.each_with_index do |(u, pu), i|
      entries[(i + 1)..].each do |(v, pv)|
        first_u, last_u = pu.first, pu.last
        first_v, last_v = pv.first, pv.last
        reason =
          if pu == pv then "Same name"
          elsif last_u == last_v && close?(first_u, first_v) then "First names nearly the same"
          elsif first_u == first_v && close?(last_u, last_v) then "Last names nearly the same"
          end
        found << Pair.new(a: u, b: v, reason: reason) if reason
      end
    end
    found.sort_by { |p| [ p.reason == "Same name" ? 0 : 1, key(p.a.name) ] }
  end
end
