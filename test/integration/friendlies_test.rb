require "test_helper"

class FriendliesTest < ActionDispatch::IntegrationTest
  setup do
    organizer = User.create!(name: "Org Anizer", email: "friendly-int@example.com")
    @friendly = Friendly.create!(organizer: organizer, starts_at: 2.days.from_now, courts: 1,
                                 location: "Test Club", title: "Sunday hit")
  end

  test "a guest opens the link, claims a spot and can take it back" do
    get friendly_path(@friendly)
    assert_response :success
    assert_match "Sunday hit", response.body

    post claim_friendly_path(@friendly), params: { name: "Guest Player" }
    assert_redirected_to friendly_path(@friendly)
    spot = @friendly.spots.reload.last
    assert_equal "Guest Player", spot.name

    delete claim_friendly_path(@friendly), params: { spot_id: spot.id }
    assert_equal 0, @friendly.spots.reload.count
  end

  test "a guest can't remove someone else" do
    other = @friendly.spots.create!(name: "Someone")
    delete claim_friendly_path(@friendly), params: { spot_id: other.id }
    assert_equal 1, @friendly.spots.reload.count
  end

  test "booking needs an account" do
    get new_friendly_path
    assert_redirected_to login_path
  end

  test "only the organizer can add a court" do
    patch friendly_courts_path(@friendly), params: { change: 1 }
    assert_redirected_to login_path
    assert_equal 1, @friendly.reload.courts
  end
end
