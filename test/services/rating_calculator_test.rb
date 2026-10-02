require "test_helper"

class RatingCalculatorTest < ActiveSupport::TestCase
  setup do
    owner = User.create!(name: "Owner", email: "rating-test@example.com")
    @usta_player = User.create!(name: "Usta Player")
    @local_player = User.create!(name: "Local Player", court_report_rating: 3.9, court_report_rating_lines: 4)

    usta  = owner.tennis_teams.create!(name: "USTA Team", league_category: "USTA", rating: 4.0)
    local = owner.tennis_teams.create!(name: "Bux Team", league_category: "Local", league_name: "Bux-Mont", rating: 4.0)

    add_line(usta,  @usta_player,  "6-2")
    add_line(local, @local_player, "5-5")
  end

  def add_line(team, user, score)
    match = team.matches.create!(match_date: Time.zone.local(2026, 9, 9, 12), opponent: "Opp", result: "win")
    line  = match.match_lines.create!(line_type: "doubles", position: 1, set1_score: score, result: "win")
    line.match_line_players.create!(user: user)
  end

  test "only USTA lines feed the rating" do
    RatingCalculator.recompute!

    @usta_player.reload
    assert_equal 1, @usta_player.court_report_rating_lines
    assert @usta_player.court_report_rating > 4.0, "a 6-2 line at a 4.0 flight should rate above 4.0"

    # Her only lines are Bux-Mont, so her stale rating is cleared.
    @local_player.reload
    assert_nil @local_player.court_report_rating
    assert_equal 0, @local_player.court_report_rating_lines
  end
end
