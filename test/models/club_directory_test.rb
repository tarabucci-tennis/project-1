require "test_helper"

class ClubDirectoryTest < ActiveSupport::TestCase
  test "matches a team or site to its club" do
    assert_equal "Frog Hollow Racquet Club", ClubDirectory.find("Frogaritas", league: "Bux-Mont").name
    assert_equal "Upper Dublin", ClubDirectory.find("Upper Dublin Orchids", league: "Bux-Mont").name
    assert_equal "Radnor Valley Country Club", ClubDirectory.find("Radnor Valley CC", league: "Del-Tri").name
    assert_equal "Radnor Racquet Club", ClubDirectory.find("Radnor Racquet 1", league: "Del-Tri").name
    assert_nil ClubDirectory.find("St Albans 2", league: "Del-Tri")
    assert_nil ClubDirectory.find("Frog Hollow", league: "USTA")
  end

  test "a match's venue: listed site first, else home club or opponent's club" do
    owner = User.create!(name: "Venue Owner", email: "venue-owner@example.com")
    team = TennisTeam.create!(user: owner, name: "Legacy 9", league_category: "Local", league_name: "Del-Tri",
                              home_court: "Legacy Tennis, 4842 Ridge Ave")
    away_site = team.matches.create!(opponent: "Penn Oaks 2", match_date: 3.days.from_now,
                                     home_away: "away", location: "Brandywine Racquet Club")
    away_plain = team.matches.create!(opponent: "HPTA 2", match_date: 4.days.from_now, home_away: "away")
    home = team.matches.create!(opponent: "DVTA 1", match_date: 5.days.from_now, home_away: "home")

    assert_equal "Brandywine Racquet Club", away_site.venue.name
    assert_equal "HPTA", away_plain.venue.name
    assert_match "601 Righters Ferry Rd", away_plain.venue.address
    assert_equal "Legacy Tennis", home.venue.name
    assert_match "google.com/maps", home.venue.maps_url

    usta = TennisTeam.create!(user: owner, name: "Some USTA", league_category: "USTA")
    assert_nil usta.matches.create!(opponent: "Frog Hollow", match_date: 2.days.from_now, home_away: "away").venue
  end
end
