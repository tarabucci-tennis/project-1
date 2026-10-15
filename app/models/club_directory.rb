# Finds which club a team or site name belongs to in Bux-Mont / Del-Tri.
# Teams are named after their club ("Frog Hollow Orange", "Penn Oaks 2"), so
# a name is matched by how it starts; the longest match wins ("Radnor Valley"
# beats "Radnor"). The clubs themselves live in the `clubs` table.
module ClubDirectory
  module_function

  def leagues
    Club::LEAGUES
  end

  def find(text, league:)
    key = normalize(text)
    return nil if key.empty? || !leagues.include?(league)

    candidates = Club.in_league(league).flat_map do |club|
      ([ club.name ] + club.alias_list).map { |a| [ normalize(a), club ] }
    end
    candidates.select { |a, _| a.present? && key.start_with?(a) }.max_by { |a, _| a.length }&.last
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end
end
