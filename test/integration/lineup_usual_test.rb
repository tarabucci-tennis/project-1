require "test_helper"

# Set Lineup fills an empty lineup with who has played each line most this
# season, and shows each line's most frequent players with a count.
class LineupUsualTest < ActionDispatch::IntegrationTest
  setup do
    @captain = User.create!(name: "Cap Tain", email: "usual-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @captain, name: "Usual Club", league_category: "Local", league_name: "Del-Tri")
    TeamMembership.create!(user: @captain, tennis_team: @team, role: "captain")
    @p = %w[Ann Bea Cat Dee Eve].to_h do |n|
      u = User.create!(name: "#{n} Player", email: "#{n.downcase}-usual@example.com")
      TeamMembership.create!(user: u, tennis_team: @team, role: "player")
      [ n, u ]
    end
    post session_path, params: { email: @captain.email, password: "tennis-123" }
  end

  # One played match: { line position => [players] }.
  def played(days_ago, lines)
    m = @team.matches.create!(match_date: days_ago.days.ago, opponent: "Club #{days_ago}", result: "win")
    lines.each do |pos, names|
      line = m.match_lines.create!(line_type: "doubles", position: pos, set1_score: "6-3", result: "win")
      names.each { |n| line.match_line_players.create!(user: @p[n]) }
    end
    m
  end

  test "an empty lineup is filled from who played each line most, with counts" do
    played(30, 1 => %w[Ann Bea], 2 => %w[Cat Dee])
    played(23, 1 => %w[Ann Bea], 2 => %w[Cat Eve])
    played(16, 1 => %w[Ann Cat], 2 => %w[Bea Dee])
    upcoming = @team.matches.create!(match_date: 5.days.from_now, opponent: "Next Club")

    get edit_team_match_lineup_path(@team, upcoming)
    assert_response :success
    assert_match "who has played each line most this season (from 3 matches", response.body
    assert_match "Ann Player <strong>3 of 3</strong>", response.body
    assert_match "Bea Player <strong>2 of 3</strong>", response.body

    slots = upcoming.reload.lineup.lineup_slots.order(:id).group_by(&:position)
    picked = ->(slot) { css_select("select[name='slots[#{slot.id}][user_id]'] option[selected]").map { |o| o["value"].to_i } }
    assert_equal [ @p["Ann"].id, @p["Bea"].id ].sort, slots[1].flat_map(&picked).sort
    assert_equal [ @p["Cat"].id, @p["Dee"].id ].sort, slots[2].flat_map(&picked).sort
    assert upcoming.lineup.lineup_slots.all? { |s| s.user_id.nil? }, "nothing saved just by opening the page"
  end

  test "a player who said she can't play isn't filled in" do
    played(30, 1 => %w[Ann Bea])
    played(23, 1 => %w[Ann Bea])
    played(16, 1 => %w[Ann Cat])
    upcoming = @team.matches.create!(match_date: 5.days.from_now, opponent: "Next Club")
    Availability.create!(user: @p["Ann"], match: upcoming, status: "out")

    get edit_team_match_lineup_path(@team, upcoming)
    assert_select "option[selected][value=?]", @p["Ann"].id.to_s, count: 0
    assert_select "option[selected][value=?]", @p["Bea"].id.to_s, count: 1
    assert_select "option[selected][value=?]", @p["Cat"].id.to_s, count: 1
  end

  test "with fewer than three matches of line scores, last week's lineup is used instead" do
    played(16, 1 => %w[Ann Bea])
    upcoming = @team.matches.create!(match_date: 5.days.from_now, opponent: "Next Club")

    get edit_team_match_lineup_path(@team, upcoming)
    assert_no_match "played each line most", response.body
    assert_match "Most often here:", response.body
  end

  test "Set Lineup knows each pair's record together" do
    played(30, 1 => %w[Ann Bea])
    played(23, 1 => %w[Ann Bea])
    upcoming = @team.matches.create!(match_date: 5.days.from_now, opponent: "Next Club")

    get edit_team_match_lineup_path(@team, upcoming)
    pairs = JSON.parse(css_select("form[data-lineup-pick-pairs-value]").first["data-lineup-pick-pairs-value"])
    key = [ @p["Ann"].id, @p["Bea"].id ].sort.join("-")
    assert_equal({ "w" => 2, "l" => 0, "court" => "Doubles 1" }, pairs[key])
    assert_select ".cr-lineup-pair[data-lineup-pick-target=pair]"
  end
end
