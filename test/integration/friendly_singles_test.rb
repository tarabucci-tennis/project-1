require "test_helper"

# Friendlies can be singles (2 a court) or doubles (4); round robins are always
# doubles (Tara, Nov 24 2026).
class FriendlySinglesTest < ActionDispatch::IntegrationTest
  setup do
    @org = User.create!(name: "Singles Org", email: "singles-org@example.com", password: "tennis-123")
    post session_path, params: { email: @org.email, password: "tennis-123" }
  end

  def book(kind, format)
    post friendlies_path, params: { friendly: { kind: kind, format: format, title: "", start_date: 2.days.from_now.to_date.iso8601,
                                                start_time: "09:00", duration: "90", sets_count: 3 } }
    Friendly.order(:id).last
  end

  test "a singles friendly: 2 names make a court, the lineup is one-on-one" do
    fr = book("friendly", "singles")
    assert fr.singles?
    %w[Tara Rebecca Amy].each { |n| fr.spots.create!(name: n) }
    fr.reload
    assert_equal 1, fr.courts_needed
    assert_equal %w[Tara Rebecca], fr.player_names
    assert_equal [ "Amy" ], fr.waitlist.map(&:name)
    assert_equal 1, fr.players_for_next_court
    fr.generate_lineup!(rng: Random.new(3))
    assert fr.lineup_sets.all? { |s| s["courts"].map(&:size) == [ 2 ] }

    get friendly_path(fr)
    assert_select ".cr-rp-eyebrow", text: /Friendly · Singles/
    assert_select ".cr-fr-court-row .cr-fr-pair", 6 # 3 sets × one player a side
    assert_match(/Ct 1: (Tara vs Rebecca|Rebecca vs Tara)/, ApplicationController.helpers.friendly_lineup_text(fr))
  end

  test "4 singles players get 2 courts and new opponents each set" do
    fr = book("friendly", "singles")
    %w[A B C D].each { |n| fr.spots.create!(name: n) }
    fr.reload.generate_lineup!(rng: Random.new(5))
    meetings = fr.lineup_sets.flat_map { |s| s["courts"].map(&:sort) }
    assert_equal 2, fr.lineup_sets.first["courts"].size
    assert_equal meetings.size, meetings.uniq.size, "nobody plays the same opponent twice in 3 sets"
  end

  test "a round robin is always doubles, even if singles is sent" do
    rr = book("round_robin", "singles")
    assert_equal "doubles", rr.format
    assert_not rr.singles?
    assert_equal 4, rr.per_court
  end
end
