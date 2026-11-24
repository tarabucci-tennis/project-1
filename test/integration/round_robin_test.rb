require "test_helper"

# Round robin vs friendly (Tara, Nov 24 2026). Round robin: everyone plays,
# extras take turns sitting out. Friendly: full courts only, extras wait.
class RoundRobinTest < ActionDispatch::IntegrationTest
  setup do
    @org = User.create!(name: "RR Organizer", email: "rr-org@example.com", password: "tennis-123")
    post session_path, params: { email: @org.email, password: "tennis-123" }
  end

  def book(kind)
    post friendlies_path, params: { friendly: { kind: kind, title: "", start_date: 2.days.from_now.to_date.iso8601,
                                                start_time: "09:00", duration: "120", sets_count: 3 } }
    Friendly.order(:id).last
  end

  test "a round robin with 6 people: one court, everyone plays, 2 sit out each set in turn" do
    rr = book("round_robin")
    assert rr.round_robin?
    assert_equal "Round robin", rr.title
    6.times { |i| rr.spots.create!(name: "RR P#{i}") }
    rr.reload
    assert_equal 1, rr.courts_needed
    assert_equal 6, rr.playing_spots.size
    assert_empty rr.waitlist
    assert_equal 2, rr.sitting_per_set
    rr.generate_lineup!(rng: Random.new(1))
    sat = rr.lineup_sets.flat_map { |s| s["sitting"] }
    assert_equal 6, sat.size
    assert_equal 6, sat.uniq.size, "everyone sits exactly once over 3 sets"

    get friendly_path(rr)
    assert_select ".cr-rp-eyebrow", text: /Round robin · organized by/
    assert_match(/2 sit out each set, taking turns/, response.body)
  end

  test "a friendly with 6 people keeps full courts: 4 play, 2 wait" do
    fr = book("friendly")
    6.times { |i| fr.spots.create!(name: "FR P#{i}") }
    fr.reload
    assert_equal 4, fr.playing_spots.size
    assert_equal 2, fr.waitlist.size
    get friendly_path(fr)
    assert_select ".cr-rp-eyebrow", text: /Friendly · organized by/
  end

  test "the booking form offers the type, and cards say Round robin" do
    get new_friendly_path(kind: "round_robin")
    assert_select "select[name='friendly[kind]'] option[selected][value=round_robin]"
    rr = book("round_robin")
    get friendlies_path
    assert_select ".cr-band-card", text: /Round robin/
    assert_match(/Round robin!/, ApplicationController.helpers.friendly_invite_text(rr))
  end
end
