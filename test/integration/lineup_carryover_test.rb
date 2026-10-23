require "test_helper"

# Lineups barely change week to week: a new lineup starts from last week's,
# and each line shows who played it last week.
class LineupCarryoverTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Cap Tain", email: "carry-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Carry Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @players = %w[Ann Bea Cat Dee].map do |n|
      u = User.create!(name: "#{n} Player", email: "#{n.downcase}-carry@example.com")
      TeamMembership.create!(user: u, tennis_team: @team, role: "player")
      u
    end
    @last = @team.matches.create!(match_date: 8.days.from_now, opponent: "Last Week Club")
    @next = @team.matches.create!(match_date: 15.days.from_now, opponent: "Next Week Club")
    post session_path, params: { email: @captain.email, password: "tennis-123" }

    get edit_team_match_lineup_path(@team, @last)
    slots = @last.reload.lineup.lineup_slots.order(:id).to_a
    @first_two = slots.first(2)
    patch team_match_lineup_path(@team, @last), params: { publish: "false", slots: {
      @first_two[0].id => { user_id: @players[0].id, confirmed: "1" },
      @first_two[1].id => { user_id: @players[1].id, confirmed: "1" }
    } }
  end

  test "a new lineup is filled in from last week's, unsaved until the captain saves" do
    get edit_team_match_lineup_path(@team, @next)
    assert_response :success
    assert_match "Filled in from last week", response.body
    assert_select "option[selected][value=?]", @players[0].id.to_s
    assert_select "option[selected][value=?]", @players[1].id.to_s
    assert_match "Last week: Ann Player", response.body
    assert @next.reload.lineup.lineup_slots.all? { |s| s.user_id.nil? }, "nothing saved just by opening the page"
  end

  test "a lineup that already has players isn't overwritten" do
    get edit_team_match_lineup_path(@team, @next)
    slot = @next.reload.lineup.lineup_slots.order(:id).first
    slot.update!(user: @players[2])
    get edit_team_match_lineup_path(@team, @next)
    assert_no_match "Filled in from last week", response.body
    assert_select "option[selected][value=?]", @players[2].id.to_s
    assert_match "Last week: Ann Player", response.body
  end

  test "a captain can write in a sub who isn't on the roster, and pick them again later" do
    get edit_team_match_lineup_path(@team, @next)
    assert_match "+ Write in a sub…", response.body
    slot = @next.reload.lineup.lineup_slots.order(:id).second
    patch team_match_lineup_path(@team, @next), params: { publish: "false", slots: {
      slot.id => { user_id: "sub", sub_name: "  Sally   Sub ", confirmed: "1" }
    } }
    sub = slot.reload.user
    assert_equal "Sally Sub", sub.name
    assert_not @team.members.include?(sub), "subs aren't added to the roster"

    patch team_match_lineup_path(@team, @next), params: { publish: "false", slots: {
      slot.id => { user_id: "sub", sub_name: "sally sub", confirmed: "1" }
    } }
    assert_equal sub, slot.reload.user, "the same name reuses the same person"

    get edit_team_match_lineup_path(@team, @next)
    assert_select "optgroup[label=Subs] option[value=?]", sub.id.to_s, text: "Sally Sub (sub)"
  end
end
