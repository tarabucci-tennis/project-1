require "test_helper"

# Captains can take players off lines, move them between lines in one save,
# and clear the whole lineup.
class LineupEditClearTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Clear Cap", email: "clear-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Clear Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @ann, @bea = %w[Ann Bea].map do |n|
      u = User.create!(name: "#{n} Player", email: "#{n.downcase}-clear@example.com")
      TeamMembership.create!(user: u, tennis_team: @team, role: "player")
      u
    end
    @match = @team.matches.create!(match_date: 6.days.from_now, opponent: "Rival Club")
    post session_path, params: { email: @captain.email, password: "tennis-123" }
    get edit_team_match_lineup_path(@team, @match)
    @s1, @s2, @s3 = @match.reload.lineup.lineup_slots.order(:id).first(3)
    save(@s1 => @ann.id, @s2 => @bea.id)
  end

  def save(picks)
    patch team_match_lineup_path(@team, @match), params: { publish: "false",
      slots: picks.to_h { |slot, uid| [ slot.id, { user_id: uid.to_s, confirmed: "1" } ] } }
  end

  test "choosing no player takes her off the line" do
    save(@s1 => "")
    assert_nil @s1.reload.user_id
    assert_equal @bea.id, @s2.reload.user_id
  end

  test "players can swap or move lines in one save" do
    save(@s1 => @bea.id, @s2 => @ann.id)
    assert_equal @bea.id, @s1.reload.user_id
    assert_equal @ann.id, @s2.reload.user_id

    save(@s1 => "", @s2 => "", @s3 => @ann.id)
    assert_equal @ann.id, @s3.reload.user_id
    assert_nil @s1.reload.user_id
  end

  test "the same player on two lines is refused with a clear message" do
    save(@s1 => @ann.id, @s3 => @ann.id)
    assert_redirected_to edit_team_match_lineup_path(@team, @match)
    assert_match "Ann Player can only be on one line", flash[:alert]
    assert_nil @s3.reload.user_id
  end

  test "clearing every line empties the lineup" do
    save(@s1 => "", @s2 => "", @s3 => "")
    assert @match.lineup.lineup_slots.reload.all? { |s| s.user_id.nil? }
  end

  test "the page has a remove button on every spot and Clear lineup" do
    get edit_team_match_lineup_path(@team, @match)
    assert_equal css_select("select[data-lineup-pick-target='select']").size, css_select("button.cr-lineup-clear").size
    assert_select "button.cr-lineup-clear-all", text: "Clear lineup"
  end
end
