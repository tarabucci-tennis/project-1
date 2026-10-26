require "test_helper"

# The "Where" box on Book a friendly suggests places as you type: league clubs
# and the organizer's own earlier friendly places, all from Court Report.
class FriendlyPlaceSuggestionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Place Picker", email: "fr-places@example.com", password: "tennis-123")
    post session_path, params: { email: @user.email, password: "tennis-123" }
  end

  test "the Where box carries clubs and my earlier places" do
    Club.create!(league: "Del-Tri", name: "Sample Racquet Club", address: "1 Court Rd, Wayne, PA 19087")
    @user.organized_friendlies.create!(starts_at: 2.days.ago, location: "Kevin's Courts, 9 Lob Lane, Media, PA")

    get new_friendly_path
    assert_response :success
    box = css_select("[data-controller='place-suggest']").first
    assert box, "the Where box has suggestions"
    assert_select "input[name='friendly[location]'][autocomplete=off][data-place-suggest-target=input]"
    places = JSON.parse(box["data-place-suggest-places-value"])
    club = places.find { |p| p["name"] == "Sample Racquet Club" }
    assert_equal "Sample Racquet Club, 1 Court Rd, Wayne, PA 19087", club["value"]
    mine = places.find { |p| p["name"] == "Kevin's Courts" }
    assert_equal "9 Lob Lane, Media, PA", mine["address"]
  end

  test "another organizer's places are not suggested to me" do
    other = User.create!(name: "Someone Else", email: "fr-places-other@example.com", password: "tennis-123")
    other.organized_friendlies.create!(starts_at: 2.days.ago, location: "Private Backyard Court, 5 Hidden Way")

    get new_friendly_path
    places = JSON.parse(css_select("[data-controller='place-suggest']").first["data-place-suggest-places-value"])
    assert_nil places.find { |p| p["name"] == "Private Backyard Court" }
  end
end
