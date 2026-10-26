require "test_helper"

# Partners shouldn't repeat across sets unless the organizer wants them to.
class FriendlyPartnerRepeatsTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = User.create!(name: "Repeat Host", email: "fr-repeats@example.com", password: "tennis-123")
    @friendly = @organizer.organized_friendlies.create!(starts_at: 2.days.from_now, sets_count: 3)
    @names = %w[Ann Bea Cat Dee Eve Fay Gia Hal]
    @names.each { |n| @friendly.spots.create!(name: n) }
  end

  def pairs(friendly)
    friendly.lineup_sets.flat_map { |s| s["courts"].flat_map { |a, b, c, d| [ [ a, b ].sort, [ c, d ].sort ] } }
  end

  test "a generated lineup never repeats partners" do
    20.times do |seed|
      @friendly.generate_lineup!(rng: Random.new(seed))
      assert_equal pairs(@friendly).uniq.size, pairs(@friendly).size, "seed #{seed}"
    end
  end

  test "two subs take the same dropped player's place in every set" do
    50.times do |seed|
      @friendly.generate_lineup!(rng: Random.new(seed))
      before = @friendly.lineup_sets.deep_dup
      @friendly.spots.where(name: %w[Bea Eve]).destroy_all
      @friendly.spots.create!(name: "Zoe")
      @friendly.spots.create!(name: "Yan")
      @friendly.reload.sync_lineup_names!

      after = @friendly.reload.lineup_sets
      assert_equal pairs(@friendly).uniq.size, pairs(@friendly).size, "seed #{seed}: repeated partners"
      map = {}
      before.zip(after).each do |b, a|
        b["courts"].flatten.zip(a["courts"].flatten).each { |o, n| (map[o] ||= n) == n or flunk("seed #{seed}: #{o} replaced inconsistently") }
      end

      @friendly.spots.where(name: %w[Zoe Yan]).destroy_all
      @friendly.spots.create!(name: "Bea")
      @friendly.spots.create!(name: "Eve")
      @friendly.reload
    end
  end

  test "the organizer is told when a swap makes partners repeat" do
    @friendly.update!(lineup: { "sets" => [
      { "courts" => [ %w[Ann Bea Cat Dee], %w[Eve Fay Gia Hal] ], "sitting" => [] },
      { "courts" => [ %w[Ann Bea Eve Gia], %w[Cat Fay Dee Hal] ], "sitting" => [] }
    ] }, sets_count: 2)
    assert_equal [ [ %w[Ann Bea], [ 1, 2 ] ] ], @friendly.repeated_partnerships

    post session_path, params: { email: @organizer.email, password: "tennis-123" }
    get friendly_path(@friendly)
    assert_select "p.cr-fr-warn", text: /Ann & Bea \(Sets 1 and 2\)/
  end
end
