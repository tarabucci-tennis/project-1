require "test_helper"

# Posting a lineup says only what happened, and the lineup can be texted to
# the team with Share lineup (no email setup needed).
class LineupShareTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Share Cap", email: "share-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Share Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @ann = User.create!(name: "Ann Player", email: "ann-share@example.com")
    TeamMembership.create!(user: @ann, tennis_team: @team, role: "player")
    @match = @team.matches.create!(match_date: 5.days.from_now, opponent: "Rival Club")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
    get edit_team_match_lineup_path(@team, @match)
    @slot = @match.reload.lineup.lineup_slots.order(:id).first
  end

  test "posting goes to the match page and points to Share lineup, no email claim" do
    patch team_match_lineup_path(@team, @match), params: { publish: "true", slots: {
      @slot.id => { user_id: @ann.id, confirmed: "0" }
    } }
    assert_redirected_to team_match_path(@team, @match)
    assert_equal "Lineup posted. Tap Share lineup to text it to your team.", flash[:notice]

    follow_redirect!
    button = css_select("button.cr-share-btn").find { |b| b.text.include?("Share lineup") }
    assert button, "Share lineup button on the match page"
    text = button["data-share-text"]
    assert_includes text, "Share Club vs. Rival Club"
    assert_includes text, "Lineup:"
    # Del-Tri plays doubles only: "Line 1: Ann", first names so it fits one row.
    assert_includes text, "Line #{@slot.position}: Ann"
    assert_not_includes text, "Ann Player"
  end

  test "a draft is not shared and says so" do
    patch team_match_lineup_path(@team, @match), params: { publish: "false", slots: {
      @slot.id => { user_id: @ann.id, confirmed: "1" }
    } }
    assert_equal "Lineup saved as a draft (not posted yet).", flash[:notice]
    get team_match_path(@team, @match)
    assert_select "button.cr-share-btn", text: /Share lineup/, count: 0
  end

  test "first names on one row each; a shared first name gets a last initial" do
    sarah_b = User.create!(name: "Sarah Brautigan")
    sarah_d = User.create!(name: "Sarah Dougherty")
    [ sarah_b, sarah_d ].each { |u| TeamMembership.create!(user: u, tennis_team: @team, role: "player") }
    slots = @match.lineup.lineup_slots.order(:position, :id).to_a
    slots[0].update!(user: sarah_b)
    slots[1].update!(user: sarah_d)
    @match.lineup.update!(published: true, published_at: Time.current)
    text = ApplicationController.helpers.lineup_share_text(@match.reload)
    assert_includes text, "Sarah B. + Sarah D."
  end
end
