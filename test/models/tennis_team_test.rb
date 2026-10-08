require "test_helper"

class TennisTeamTest < ActiveSupport::TestCase
  def team(**attrs)
    TennisTeam.new({ name: "T", league_category: "USTA" }.merge(attrs))
  end

  test "Tri-Level teams play three doubles lines, one per level" do
    agc = team(team_type: "Tri-Level", flight: "Tri Level Womens 4.5-3.5 Wednesday", rating: 4.5)
    assert agc.tri_level?
    assert_equal %w[4.5 4.0 3.5], agc.tri_levels
    assert_equal [ [ "doubles", 1 ], [ "doubles", 2 ], [ "doubles", 3 ] ], agc.lineup_slot_plan.keys
    assert_not agc.has_singles_line?
    assert_equal "4.0", agc.doubles_line_level(2)

    hards = team(league_name: "USTA Adult Tri-Level", flight: "Tri Level Womens 4.0-3.0 Wednesday/Sub-Flight 2")
    assert_equal %w[4.0 3.5 3.0], hards.tri_levels
  end

  test "other teams keep their formats and have no line levels" do
    usta = team(team_type: "Adult 40 & Over", rating: 4.0)
    assert_not usta.tri_level?
    assert usta.has_singles_line?
    assert_equal 4, usta.doubles_line_count
    assert_nil usta.doubles_line_level(1)

    assert_equal 6, team(league_category: "Local").doubles_line_count
  end
end
