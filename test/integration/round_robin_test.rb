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
    assert_match(/Can you play\? Add your name:\z/, ApplicationController.helpers.friendly_invite_text(rr))
  end

  test "nobody partners the same person twice, and a swap that would is refused" do
    [ 4, 5, 6, 7, 8, 9, 12 ].each do |n|
      names = (1..n).map { |i| "P#{i}" }
      50.times do |seed|
        g = FriendlyLineupGenerator.new(names, rng: Random.new(seed))
        sets = Array.new(3) { g.next_set }
        fr = Friendly.new(sets_count: 3)
        assert_empty fr.repeat_partners(sets), "#{n} players, seed #{seed}"
      end
    end

    rr = book("round_robin")
    %w[A B C D].each { |nm| rr.spots.create!(name: nm) }
    rr.update!(lineup: { "sets" => [
      { "courts" => [ %w[A B C D] ], "sitting" => [], "done" => false },
      { "courts" => [ %w[A C B D] ], "sitting" => [], "done" => false },
      { "courts" => [ %w[A D B C] ], "sitting" => [], "done" => false }
    ] })
    # Swapping B and C in set 2 would pair A+B again (they partner in set 1).
    patch swap_friendly_lineup_path(rr), params: { set: 1, a: "0-1", b: "0-2" }
    assert_equal %w[A C B D], rr.reload.lineup_sets[1]["courts"][0]
    assert_match(/A and B would be partners twice/, flash[:alert])
  end
end
