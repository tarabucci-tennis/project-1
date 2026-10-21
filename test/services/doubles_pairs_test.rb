require "test_helper"

class DoublesPairsTest < ActiveSupport::TestCase
  setup do
    owner = User.create!(name: "Pairs Owner", email: "pairs-owner@example.com")
    @a, @b, @c, @d = %w[Ann Bea Cat Dee].map { |n| User.create!(name: "#{n} Pair", ntrp_rating: 4.0) }
    @e = User.create!(name: "Eve Pair", ntrp_rating: 4.5)
    @usta = owner.tennis_teams.create!(name: "Pairs USTA", league_category: "USTA")
    [ @a, @b, @c, @d, @e ].each { |u| TeamMembership.create!(user: u, tennis_team: @usta, role: "player") }
  end

  def line!(team, date, position, players, result)
    match = team.matches.find_or_create_by!(match_date: date, opponent: "Rivals")
    line = match.match_lines.create!(line_type: "doubles", position: position, result: result, set1_score: "6-3")
    players.each { |u| line.match_line_players.create!(user: u) }
  end

  test "groups scored lines by pair with record, usual court and all-teams record" do
    line!(@usta, 3.weeks.ago, 2, [ @a, @b ], "win")
    line!(@usta, 2.weeks.ago, 2, [ @b, @a ], "loss")
    line!(@usta, 1.week.ago, 3, [ @a, @b ], "win")
    line!(@usta, 1.week.ago, 4, [ @c, @d ], "loss")
    other = @a.tennis_teams.create!(name: "Other", league_category: "USTA")
    line!(other, 1.day.ago, 2, [ @a, @b ], "win")

    dp = DoublesPairs.new(@usta)
    top = dp.pairs.first
    assert_equal [ @a, @b ].map(&:name).sort, top.players.map(&:name)
    assert_equal [ 2, 1, 3 ], [ top.wins, top.losses, top.together ]
    assert_equal [ "Doubles 1", 2 ], top.usual_court
    assert_equal [ 3, 1 ], [ top.all_wins, top.all_losses ]
    assert_equal 2, dp.pairs.size
  end

  test "USTA teams suggest unpaired roster pairs by combined rating" do
    line!(@usta, 1.week.ago, 2, [ @a, @e ], "win")
    ideas = DoublesPairs.new(@usta).ideas
    assert ideas.none? { |i| i.players.map(&:id).sort == [ @a.id, @e.id ].sort }
    assert_equal 8.5, ideas.first.combined
  end

  test "fixed-partner leagues mark regulars and subs, and skip ideas" do
    deltri = @a.tennis_teams.create!(name: "Pairs DelTri", league_category: "Local", league_name: "Del-Tri")
    3.times { |i| line!(deltri, (i + 2).weeks.ago, 1, [ @a, @b ], "win") }
    line!(deltri, 1.week.ago, 2, [ @c, @d ], "loss")
    dp = DoublesPairs.new(deltri)
    assert dp.fixed_partners?
    regular, sub = dp.pairs
    assert dp.regular?(regular)
    assert_not dp.regular?(sub)
    assert_empty dp.ideas
  end
end
