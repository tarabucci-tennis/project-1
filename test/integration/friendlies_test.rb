require "test_helper"

class FriendliesTest < ActionDispatch::IntegrationTest
  setup do
    organizer = User.create!(name: "Org Anizer", email: "friendly-int@example.com")
    @friendly = Friendly.create!(organizer: organizer, starts_at: 2.days.from_now,
                                 location: "Test Club", title: "Sunday hit")
  end

  test "a guest opens the link, claims a spot and can take it back" do
    get friendly_path(@friendly)
    assert_response :success
    assert_match "Sunday hit", response.body

    post claim_friendly_path(@friendly), params: { name: "Guest Player" }
    assert_redirected_to friendly_path(@friendly)
    assert_match "waitlist", flash[:notice], "1 name isn't a full court yet"
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

  test "only the organizer can make the lineup" do
    %w[A B C D].each { |n| @friendly.spots.create!(name: n) }
    post friendly_lineup_path(@friendly)
    assert_redirected_to login_path
    assert_not @friendly.reload.lineup?
  end

  test "the organizer generates, swaps and prints the lineup" do
    organizer = @friendly.organizer
    organizer.update!(password: "tennis-123")
    post session_path, params: { email: organizer.email, password: "tennis-123" }
    %w[Ann Bea Cat Dee Eve].each { |n| @friendly.spots.create!(name: n) }

    get friendly_path(@friendly)
    assert_match "4 players = 1 court", response.body
    assert_match "1 on the waitlist", response.body

    post friendly_lineup_path(@friendly)
    assert @friendly.reload.lineup?
    follow_redirect!
    assert_select ".cr-fr-set", 3
    assert_match "Copy as text", response.body

    before = @friendly.lineup_sets[0]
    patch swap_friendly_lineup_path(@friendly), params: { set: 0, a: "0-0", b: "0-3" }
    after = @friendly.reload.lineup_sets[0]
    assert_equal before["courts"][0][3], after["courts"][0][0]
    assert_not_includes after["courts"].flatten, "Eve", "the 5th name waits"

    get friendlies_path
    assert_match "Sunday hit", response.body
    assert_match "Upcoming", response.body
  end
end
