require "test_helper"

# Split court times (Tara, Nov 17 2026): each line can have its own start
# time; the shared lineup groups lines by time; nothing carries to next week.
class LineStartTimesTest < ActionDispatch::IntegrationTest
  setup do
    @cap = User.create!(name: "Annie Duke", email: "time-cap@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: @cap, name: "Time Legacy", league_category: "Local", league_name: "Del-Tri", line_format: "3D")
    TeamMembership.create!(user: @cap, tennis_team: @team, role: "captain")
    @people = %w[Tracy Jen Annie2 Denise Tara Heather].map.with_index do |n, i|
      u = User.create!(name: "#{n} Time#{i}")
      TeamMembership.create!(user: u, tennis_team: @team, role: "player")
      u
    end
    @match = @team.matches.create!(opponent: "Penn Oaks", match_date: 3.days.from_now, match_time: "9:00 AM")
    post session_path, params: { email: @cap.email, password: "tennis-123" }
    get edit_team_match_lineup_path(@team, @match)
    @lineup = @match.reload.lineup
  end

  def fill_lineup
    @lineup.lineup_slots.order(:position, :id).each_with_index { |s, i| s.update!(user: @people[i]) }
  end

  test "typed times are tidied" do
    assert_equal "10:30 AM", LineStartTime.normalize("1030")
    assert_equal "10:30 AM", LineStartTime.normalize("10:30 a.m.")
    assert_equal "2:00 PM", LineStartTime.normalize("2")
    assert_nil LineStartTime.normalize(" ")
  end

  test "times are saved per line; the match time means no separate time" do
    fill_lineup
    patch team_match_lineup_path(@team, @match), params: { publish: "true",
      line_times: { "doubles-1" => "__other", "doubles-2" => "", "doubles-3" => "9:00 AM" },
      line_times_other: { "doubles-1" => "1030am" } }
    times = @lineup.lineup_slots.order(:position).group_by(&:position).transform_values { |s| s.map(&:start_time).uniq }
    assert_equal [ "10:30 AM" ], times[1]
    assert_equal [ nil ], times[2]
    assert_equal [ nil ], times[3]

    get edit_team_match_lineup_path(@team, @match)
    assert_select "select#line_time_doubles-2 option", text: "10:30 AM"
  end

  test "the shared text groups lines under each start time, earliest first" do
    fill_lineup
    @lineup.lineup_slots.where(position: 1).update_all(start_time: "10:30 AM")
    @lineup.update!(published: true, published_at: Time.current)
    text = ApplicationController.helpers.lineup_share_text(@match.reload)
    assert_match(/Starting at 9:00 AM:\nLine 2: Annie2 \+ Denise\nLine 3: Tara \+ Heather\n\nStarting at 10:30 AM:\nLine 1: Tracy \+ Jen/, text)
    # The date row leaves out the match time when the times are split.
    assert_includes text, "📅 #{@match.match_date.strftime('%a, %b %-d')}\n"
    assert_not_includes text, "· 9:00 AM"
  end

  test "one start time: no headings" do
    fill_lineup
    @lineup.update!(published: true, published_at: Time.current)
    text = ApplicationController.helpers.lineup_share_text(@match.reload)
    assert_no_match(/Starting at/, text)
    assert_includes text, "· 9:00 AM" # one time: it stays in the date row
  end

  test "next week's lineup doesn't copy the times" do
    fill_lineup
    @lineup.lineup_slots.update_all(start_time: "10:30 AM")
    @lineup.update!(published: true, published_at: Time.current)
    next_week = @team.matches.create!(opponent: "DVTA", match_date: 10.days.from_now, match_time: "9:00 AM")
    get edit_team_match_lineup_path(@team, next_week)
    assert next_week.reload.lineup.lineup_slots.all? { |s| s.start_time.nil? }
    assert_select "select.cr-lineup-time-select option[selected]", count: 0
  end
end
