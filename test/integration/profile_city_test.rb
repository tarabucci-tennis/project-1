require "test_helper"

class ProfileCityTest < ActionDispatch::IntegrationTest
  setup do
    @player = User.create!(name: "City Player", email: "city-player@example.com", password: "tennis-123")
    post session_path, params: { email: @player.email, password: "tennis-123" }
  end

  test "a player adds, changes and removes their own city" do
    get profile_path
    assert_match "Add your city (optional)", response.body

    post profile_city_path, params: { city: "  Villanova,   PA " }
    assert_equal "Villanova, PA", @player.reload.location
    follow_redirect!
    assert_select ".cr-pp-loc", text: "Villanova, PA"
    assert_match "Edit city", response.body

    post profile_city_path, params: { city: "" }
    assert_nil @player.reload.location
  end

  test "the city box only shows on your own profile" do
    other = User.create!(name: "Other Player", email: "other-city@example.com", location: "Wayne, PA")
    get player_path(other)
    assert_select ".cr-pp-loc", text: "Wayne, PA"
    assert_no_match "Edit city", response.body
    assert_no_match "Add your city", response.body
  end
end
