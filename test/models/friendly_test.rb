require "test_helper"

class FriendlyTest < ActiveSupport::TestCase
  setup do
    @organizer = User.create!(name: "Org Anizer", email: "friendly-org@example.com")
    @friendly = Friendly.create!(organizer: @organizer, starts_at: 2.days.from_now)
  end

  def add(*names)
    names.each { |n| @friendly.spots.create!(name: n) }
    @friendly.reload
  end

  def everyone_once?(set, names)
    (set["courts"].flatten + set["sitting"]).sort == names.sort
  end

  test "courts come from the names: every 4 = 1 court, the rest wait" do
    assert @friendly.token.present?
    add("A", "B", "C")
    assert_equal 0, @friendly.courts_needed
    assert_not @friendly.can_generate?

    add("D", "E", "F", "G", "H", "I", "J", "K", "L", "M")
    assert_equal 3, @friendly.courts_needed
    assert_equal 12, @friendly.playing_spots.size
    assert_equal [ "M" ], @friendly.waitlist.map(&:name), "the 13th waits"
    assert_equal 3, @friendly.players_for_next_court

    add("N", "O", "P")
    assert_equal 4, @friendly.courts_needed
    assert_empty @friendly.waitlist
  end

  test "someone dropping out or marked out moves the waitlist up" do
    add("A", "B", "C", "D", "E")
    assert_equal [ "E" ], @friendly.waitlist.map(&:name)
    @friendly.spots.first.update!(in_lineup: false)
    @friendly.reload
    assert_includes @friendly.player_names, "E"
    assert_empty @friendly.waitlist
  end

  test "the same name can't sign up twice" do
    add("Jane Doe")
    assert_not @friendly.spots.new(name: "jane doe").valid?
  end

  test "involving finds friendlies I organized or joined" do
    other = User.create!(name: "Someone Else", email: "friendly-other@example.com")
    @friendly.spots.create!(user: other, name: other.name)
    assert_includes Friendly.involving(@organizer), @friendly
    assert_includes Friendly.involving(other), @friendly
  end

  test "lineup: full courts only, 3 sets, new partners each set" do
    names = %w[A B C D E F G H I]
    add(*names)
    @friendly.generate_lineup!(rng: Random.new(3))
    sets = @friendly.reload.lineup_sets
    assert_equal 3, sets.size
    sets.each do |set|
      assert everyone_once?(set, names.first(8))
      assert_equal 2, set["courts"].size
      assert_empty set["sitting"]
    end
    assert_not_includes sets.flat_map { |s| s["courts"].flatten }, "I", "the 9th is on the waitlist"

    pairs = sets.flat_map { |s| s["courts"].flat_map { |a, b, c, d| [ [ a, b ].sort, [ c, d ].sort ] } }
    assert_equal pairs.size, pairs.uniq.size, "no partner twice"
  end

  test "played sets are kept when regenerating, and a new court joins" do
    add("A", "B", "C", "D", "E", "F", "G")
    @friendly.generate_lineup!(rng: Random.new(1))
    first = @friendly.lineup_sets[0]
    @friendly.mark_set_done!(0, true)

    add("H")
    assert @friendly.lineup_out_of_date?
    @friendly.generate_lineup!(rng: Random.new(2))
    sets = @friendly.reload.lineup_sets
    assert_equal first.merge("done" => true), sets[0]
    assert everyone_once?(sets[1], %w[A B C D E F G H])
    assert_equal 2, sets[1]["courts"].size
    assert_not @friendly.lineup_out_of_date?
  end

  test "swap two players in a set, but not in a played set" do
    add("A", "B", "C", "D", "E", "F", "G", "H")
    @friendly.generate_lineup!(rng: Random.new(5))
    set = @friendly.lineup_sets[0]
    a = set["courts"][0][0]
    z = set["courts"][1][3]

    assert @friendly.swap_players!(0, "0-0", "1-3")
    set = @friendly.reload.lineup_sets[0]
    assert_equal z, set["courts"][0][0]
    assert_equal a, set["courts"][1][3]

    @friendly.mark_set_done!(0, true)
    assert_not @friendly.swap_players!(0, "0-0", "0-1")
    assert_not @friendly.swap_players!(1, "0-0", "9-9")
  end

  test "optional end time on the same day" do
    @friendly.update!(starts_at: Time.zone.local(2026, 11, 7, 9, 0), end_time: "11:00")
    assert_equal Time.zone.local(2026, 11, 7, 11, 0), @friendly.reload.ends_at
    assert_equal "9:00 – 11:00 AM", @friendly.time_label

    @friendly.update!(end_time: "13:30")
    assert_equal "9:00 AM – 1:30 PM", @friendly.reload.time_label

    assert_not @friendly.update(end_time: "8:00"), "can't end before it starts"

    @friendly.reload.update!(end_time: "")
    assert_nil @friendly.reload.ends_at
    assert_equal "9:00 AM", @friendly.time_label
  end

  test "court length: 1½ hours, 2 hours, other or not sure" do
    start = Time.zone.local(2026, 11, 7, 9, 0)
    @friendly.update!(starts_at: start, duration: "90")
    assert_equal start + 90.minutes, @friendly.ends_at
    assert_equal "9:00 – 10:30 AM", @friendly.time_label

    @friendly.update!(duration: "120")
    assert_equal start + 2.hours, @friendly.reload.ends_at

    @friendly.update!(duration: "custom", end_time: "12:15")
    assert_equal "9:00 AM – 12:15 PM", @friendly.reload.time_label

    @friendly.update!(duration: "none", end_time: "12:15")
    assert_nil @friendly.reload.ends_at

    fresh = Friendly.find(@friendly.id)
    fresh.ends_at = start + 90.minutes
    assert_equal "90", fresh.duration
  end
end
