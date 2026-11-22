require "test_helper"

# Tara, Nov 17 2026: a lineup saved as a draft says "Draft" wherever a captain looks.
class LineupDraftLabelTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Draft Cap", email: "draft-cap@example.com", password: "tennis-123")
    @player = User.create!(name: "Draft Player", email: "draft-player@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Draft Aces", league_category: "USTA")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: @player, tennis_team: @team, role: "player")
    @match = @team.matches.create!(opponent: "Rivals", match_date: 4.days.from_now)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  def save_draft
    get edit_team_match_lineup_path(@team, @match)
    slot = @match.reload.lineup.lineup_slots.order(:id).first
    slot.update!(user: @player)
    patch team_match_lineup_path(@team, @match), params: { publish: "false" }
  end

  test "an opened-but-empty lineup isn't a draft; a saved one is, everywhere" do
    sign_in(@cap)
    get edit_team_match_lineup_path(@team, @match)
    assert_select ".cr-lineup-status", count: 0
    assert_not @match.reload.lineup.draft?

    save_draft
    assert @match.reload.lineup.draft?
    get edit_team_match_lineup_path(@team, @match)
    assert_select ".cr-lineup-status.is-draft", text: /Draft · saved .* players can't see it/
    get team_path(@team)
    assert_select ".cr-sched-pill-draft", text: "Draft"
    get lineups_dashboard_path
    assert_select ".cr-lu-status.is-draft", text: "Draft"
    get team_match_path(@team, @match)
    assert_select ".cr-lineup-status.is-draft", text: /Draft lineup/
  end

  test "players never see the draft" do
    sign_in(@cap)
    save_draft
    sign_in(@player)
    get team_path(@team)
    assert_select ".cr-sched-pill-draft", count: 0
    get lineups_dashboard_path
    assert_select ".cr-lu-status.is-draft", count: 0
    get team_match_path(@team, @match)
    assert_select ".cr-lineup-status", count: 0
  end

  test "after posting, the page says Posted and the button is Save changes" do
    sign_in(@cap)
    get edit_team_match_lineup_path(@team, @match)
    patch team_match_lineup_path(@team, @match), params: { publish: "true" }
    get edit_team_match_lineup_path(@team, @match)
    assert_select ".cr-lineup-status.is-posted", text: /Posted/
    assert_select "button", text: "Save changes"
    assert_select "button", text: "Save Draft", count: 0
  end
end
