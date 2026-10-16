require "test_helper"

class RatingsHiddenTest < ActionDispatch::IntegrationTest
  setup do
    @player = User.create!(name: "Rating Player", email: "rating-player@example.com", password: "tennis-123")
    @admin = User.create!(name: "Rating Admin", email: "rating-admin@example.com", password: "tennis-123", admin: true)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "players can't open the Ratings pages and don't see the button" do
    sign_in(@player)
    get ratings_path
    assert_redirected_to teams_path
    get ratings_upload_path
    assert_redirected_to teams_path
    get teams_path
    assert_no_match "📈 Ratings", response.body
  end

  test "admins still can" do
    sign_in(@admin)
    get ratings_path
    assert_response :success
  end
end
