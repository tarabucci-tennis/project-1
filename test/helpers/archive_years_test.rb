require "test_helper"

# Past Seasons on My Teams: league ▸ year ▸ teams.
class ArchiveYearsTest < ActionView::TestCase
  include ApplicationHelper

  def team(season, start = nil)
    TennisTeam.new(name: "T", season_name: season, start_date: start)
  end

  test "years come from the season label" do
    assert_equal "2026", archive_year(team("Spring 2026"))
    assert_equal "2025-26", archive_year(team("Fall/Winter 2025-26 (Completed)"))
    assert_equal "2024", archive_year(team(nil, Date.new(2024, 4, 1)))
  end

  test "rows under a year show just the season" do
    assert_equal "Spring", archive_season_part(team("Spring 2026"))
    assert_equal "Fall/Winter", archive_season_part(team("Fall/Winter 2025-26 (Completed)"))
  end

  test "newest year first" do
    teams = [ team("Spring 2025"), team("Fall/Winter 2025-26"), team("Spring 2026") ]
    assert_equal [ "2026", "2025-26", "2025" ], archive_by_year(teams).map(&:first)
  end
end
