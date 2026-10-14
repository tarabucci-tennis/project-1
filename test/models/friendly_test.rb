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

  test "courts come from the names: every 4 = 1 court, the rest sit" do
    assert @friendly.token.present?
    add("A", "B", "C")
    assert_equal 0, @friendly.courts_needed
    assert_not @friendly.can_generate?

    add("D", "E", "F", "G", "H", "I")
    assert_equal 2, @friendly.courts_needed
    assert_equal 1, @friendly.sitting_each_set
    assert_equal 3, @friendly.players_for_next_court
  end

  test "players taken out of the rotation don't count" do
    add("A", "B", "C", "D", "E")
    @friendly.spots.last.update!(in_lineup: false)
    assert_equal 4, @friendly.reload.playing_spots.size
    assert_equal 0, @friendly.sitting_each_set
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

  test "lineup: 3 sets, new partners each set, sit-outs taken in turn" do
    names = %w[A B C D E F G H I]
    add(*names)
    @friendly.generate_lineup!(rng: Random.new(3))
    sets = @friendly.reload.lineup_sets
    assert_equal 3, sets.size
    sets.each do |set|
      assert everyone_once?(set, names)
      assert_equal 2, set["courts"].size
      assert_equal 1, set["sitting"].size
    end
    assert_equal 3, sets.flat_map { |s| s["sitting"] }.uniq.size, "nobody sits twice"

    pairs = sets.flat_map { |s| s["courts"].flat_map { |a, b, c, d| [ [ a, b ].sort, [ c, d ].sort ] } }
    assert_equal pairs.size, pairs.uniq.size, "no partner twice"
  end

  test "played sets are kept when regenerating, and a late arrival gets in" do
    add("A", "B", "C", "D", "E")
    @friendly.generate_lineup!(rng: Random.new(1))
    first = @friendly.lineup_sets[0]
    @friendly.mark_set_done!(0, true)

    add("F")
    assert @friendly.lineup_out_of_date?
    @friendly.generate_lineup!(rng: Random.new(2))
    sets = @friendly.reload.lineup_sets
    assert_equal first.merge("done" => true), sets[0]
    assert everyone_once?(sets[1], %w[A B C D E F])
    assert_includes sets[1]["courts"].flatten, "F", "the late arrival plays the next set"
    assert_not @friendly.lineup_out_of_date?
  end

  test "swap two players in a set, but not in a played set" do
    add("A", "B", "C", "D", "E")
    @friendly.generate_lineup!(rng: Random.new(5))
    set = @friendly.lineup_sets[0]
    a = set["courts"][0][0]
    sitter = set["sitting"][0]

    assert @friendly.swap_players!(0, "0-0", "s-0")
    set = @friendly.reload.lineup_sets[0]
    assert_equal sitter, set["courts"][0][0]
    assert_equal [ a ], set["sitting"]

    @friendly.mark_set_done!(0, true)
    assert_not @friendly.swap_players!(0, "0-0", "0-1")
    assert_not @friendly.swap_players!(1, "0-0", "9-9")
  end
end
