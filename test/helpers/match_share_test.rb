require "test_helper"

class MatchShareTest < ActionView::TestCase
  include ApplicationHelper

  setup do
    Club.create!(league: "Bux-Mont", name: "Frog Hollow Racquet Club", address: "2115 Weber Road, Lansdale, PA 19446", aliases: "Frog")
    owner = User.create!(name: "Share Owner", email: "share-owner@example.com")
    @team = TennisTeam.create!(user: owner, name: "Advantage Us", league_category: "Local", league_name: "Bux-Mont")
  end

  test "share text has both teams, when, home/away, the club address and directions" do
    match = @team.matches.create!(opponent: "Frog Hollow Platinum", home_away: "away",
                                  match_date: Time.zone.local(2026, 10, 19, 10, 30), match_time: "10:30 am")
    text = match_share_text(match)
    assert_includes text, "🎾 Advantage Us vs. Frog Hollow Platinum"
    assert_includes text, "Bux-Mont · Mon, Oct 19 · 10:30 am · Away"
    assert_includes text, "📍 Frog Hollow Racquet Club, 2115 Weber Road, Lansdale, PA 19446"
    assert_includes text, "https://www.google.com/maps/search/?api=1&query=Frog%20Hollow"
  end

  test "no location known: no address lines" do
    usta = TennisTeam.create!(user: @team.user, name: "Some USTA", league_category: "USTA")
    match = usta.matches.create!(opponent: "Somebody", home_away: "away", match_date: Time.zone.local(2026, 10, 20, 9))
    text = match_share_text(match)
    assert_includes text, "Some USTA vs. Somebody"
    assert_not_includes text, "📍"
  end

  test "team colors: dots from the captain's words, and in the shared text" do
    @team.update!(team_colors: "Any pink & black")
    assert_equal [ "#ec4899", "#111827" ], @team.color_swatches
    match = @team.matches.create!(opponent: "Somebody", home_away: "home", match_date: Time.zone.local(2026, 10, 26, 13, 30))
    assert_includes match_share_text(match), "👕 We wear: Any pink & black"

    @team.update!(team_colors: "All black")
    assert_equal [ "#111827" ], @team.color_swatches
  end
end
