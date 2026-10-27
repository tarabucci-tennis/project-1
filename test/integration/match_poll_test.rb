require "test_helper"

# The "Can you play?" link: captains text it, players tap Yes / No by their
# name without an account, and the answer is their availability.
class MatchPollTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Poll Cap", email: "poll-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Poll Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @ann = User.create!(name: "Ann Player", email: "ann-poll@example.com")
    TeamMembership.create!(user: @ann, tennis_team: @team, role: "player")
    @match = @team.matches.create!(match_date: 4.days.from_now, opponent: "Rival Club")
  end

  test "the captain's button carries the text and a private link" do
    post session_path, params: { email: @captain.email, password: "tennis-123" }
    get team_match_path(@team, @match)
    button = css_select("button.cr-share-btn").find { |b| b.text.include?("Ask who can play") }
    assert button, "Ask who can play button"
    assert_includes button["data-share-text"], "Can you play? Tap your name, then Yes or No"
    token = @match.reload.availability_token
    assert token.present?
    assert_equal match_poll_url(token), button["data-share-url"]
  end

  test "a player answers without an account and it saves as availability" do
    token = @match.availability_token!
    get match_poll_path(token)
    assert_response :success
    assert_select ".cr-poll-name", text: /Ann Player/

    post match_poll_answer_path(token), params: { user_id: @ann.id, status: "in" }
    assert_redirected_to match_poll_path(token, anchor: "p#{@ann.id}")
    assert_equal "in", @match.availability_for(@ann).status

    post match_poll_answer_path(token), params: { user_id: @ann.id, status: "out" }
    assert_equal "out", @match.availability_for(@ann).reload.status

    get match_poll_path(token)
    assert_select ".cr-poll-row-me .cr-poll-you", text: "You"
    assert_select ".cr-poll-row-me .cr-poll-btn-no.is-on"
  end

  test "only people on the team can be answered for, and bad links are refused" do
    stranger = User.create!(name: "Not Here", email: "not-here-poll@example.com")
    token = @match.availability_token!
    post match_poll_answer_path(token), params: { user_id: stranger.id, status: "in" }
    assert_nil @match.availability_for(stranger)

    get match_poll_path("nope")
    assert_response :not_found
  end

  test "the captain sees who said yes on the Set Lineup page" do
    Availability.create!(user: @ann, match: @match, status: "in")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
    get edit_team_match_lineup_path(@team, @match)
    assert_select ".cr-lineup-said", text: /Can play: Ann Player/
  end
end
