require "test_helper"

# Optional scores on a friendly's sets: anyone with the link can add the games
# for each pair on a court, or leave it blank.
class FriendlyScoresTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = User.create!(name: "Score Host", email: "fr-scores@example.com", password: "tennis-123")
    @friendly = @organizer.organized_friendlies.create!(
      starts_at: 1.day.from_now, sets_count: 2,
      lineup: { "sets" => [
        { "courts" => [ %w[Ann Bea Cat Dee ] ], "sitting" => [] },
        { "courts" => [ %w[Ann Cat Bea Dee ] ], "sitting" => [] }
      ] }
    )
  end

  test "every court offers an optional score box" do
    get friendly_path(@friendly)
    assert_response :success
    assert_select "details.cr-fr-score-edit summary", text: "+ Add score", count: 2
    assert_select ".cr-fr-score-val", count: 0
  end

  test "anyone with the link can save a score and it shows" do
    patch friendly_court_score_path(@friendly, set: 0, court: 0), params: { a: "6", b: "4" }
    assert_redirected_to friendly_path(@friendly, anchor: "set-1")
    assert_equal [ [ 6, 4 ] ], @friendly.reload.lineup_sets[0]["scores"]

    get friendly_path(@friendly)
    assert_select ".cr-fr-score-val .cr-fr-score-win", text: "6"
    assert_select "details.cr-fr-score-edit summary", text: "Edit score", count: 1
  end

  test "both blank clears the score" do
    patch friendly_court_score_path(@friendly, set: 1, court: 0), params: { a: "3", b: "6" }
    patch friendly_court_score_path(@friendly, set: 1, court: 0), params: { a: "", b: "" }
    assert_equal [ nil ], @friendly.reload.lineup_sets[1]["scores"]
  end

  test "a half-filled or bad score is refused" do
    patch friendly_court_score_path(@friendly, set: 0, court: 0), params: { a: "6", b: "" }
    assert_equal "Scores must be whole numbers (or leave both blank).", flash[:alert]
    patch friendly_court_score_path(@friendly, set: 0, court: 5), params: { a: "6", b: "4" }
    assert_nil @friendly.reload.lineup_sets[0]["scores"]
  end

  test "swapping players in a set drops its scores" do
    @friendly.set_court_score!(0, 0, "6", "2")
    @friendly.swap_players!(0, "0-1", "0-2")
    assert_nil @friendly.reload.lineup_sets[0]["scores"]
  end
end
