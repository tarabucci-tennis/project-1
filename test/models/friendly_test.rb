require "test_helper"

class FriendlyTest < ActiveSupport::TestCase
  setup do
    @organizer = User.create!(name: "Org Anizer", email: "friendly-org@example.com")
    @friendly = Friendly.create!(organizer: @organizer, starts_at: 2.days.from_now, courts: 1)
  end

  test "gets a share token and fills 4 per court, then a waitlist" do
    assert @friendly.token.present?
    6.times { |i| @friendly.spots.create!(name: "Player #{i}") }
    @friendly.reload
    assert_equal 4, @friendly.players.size
    assert_equal %w[Player\ 4 Player\ 5], @friendly.waitlist.map(&:name)
    assert @friendly.full?
    assert_equal 0, @friendly.open_spots
  end

  test "two courts hold 8 and someone dropping out moves the waitlist up" do
    @friendly.update!(courts: 2)
    9.times { |i| @friendly.spots.create!(name: "P#{i}") }
    @friendly.reload
    assert_equal [ 4, 4 ], @friendly.courts_with_players.map { |c| c.compact.size }
    assert_equal [ "P8" ], @friendly.waitlist.map(&:name)

    @friendly.spots.first.destroy
    assert_includes @friendly.reload.players.map(&:name), "P8"
  end

  test "the same name can't claim twice" do
    @friendly.spots.create!(name: "Jane Doe")
    dup = @friendly.spots.new(name: "jane doe")
    assert_not dup.valid?
  end

  test "involving finds friendlies I organized or joined" do
    other = User.create!(name: "Someone Else", email: "friendly-other@example.com")
    @friendly.spots.create!(user: other, name: other.name)
    assert_includes Friendly.involving(@organizer), @friendly
    assert_includes Friendly.involving(other), @friendly
  end
end
