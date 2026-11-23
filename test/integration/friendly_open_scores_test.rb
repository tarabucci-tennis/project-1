require "test_helper"

# Friendly scores (Tara, Nov 23 2026): anyone with the link adds a court's score
# without signing in; each save is logged with a name; the organizer can lock.
class FriendlyOpenScoresTest < ActionDispatch::IntegrationTest
  setup do
    @org = User.create!(name: "Score Organizer", email: "score-org@example.com", password: "tennis-123")
    @fr = @org.organized_friendlies.create!(title: "Advantage Us vs Advantage Gold", starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
  end

  def save(court:, name:, sets:, pair_a: "Tara & Jen", pair_b: "Amy & Kim")
    boxes = sets.each_with_index.to_h { |(a, b), i| [ [ "set#{i + 1}_a", a.to_s ], [ "set#{i + 1}_b", b.to_s ] ] }.to_a.flatten(1).to_h
    post friendly_scores_path(@fr), params: { score: { court: court, pair_a: pair_a, pair_b: pair_b, entered_by: name }.merge(boxes) }
  end

  test "a guest adds a score without signing in, and it shows on the page" do
    save(court: 2, name: "Jen", sets: [ [ 6, 4 ], [ 4, 3 ] ])
    s = @fr.scores.find_by!(court: 2)
    assert_equal [ [ 6, 4 ], [ 4, 3 ] ], s.set_scores
    assert_equal "Jen", s.entered_by
    get friendly_path(@fr)
    assert_select ".cr-fr-score-row", text: /Court 2.*Tara & Jen.*Amy & Kim.*6–4, 4–3.*by Jen/m
  end

  test "saving the same court again replaces it and keeps a log of who changed it" do
    save(court: 1, name: "Jen", sets: [ [ 6, 4 ] ])
    save(court: 1, name: "Amy", sets: [ [ 6, 4 ], [ 2, 6 ] ])
    s = @fr.scores.find_by!(court: 1)
    assert_equal 1, @fr.scores.count
    assert_equal "6–4, 2–6", s.sets_text
    assert_equal %w[Jen Amy], s.changes_log.map { |c| c["by"] }
  end

  test "a name and a real score are required" do
    save(court: 1, name: "", sets: [ [ 6, 4 ] ])
    save(court: 1, name: "Jen", sets: [])
    save(court: 1, name: "Jen", sets: [ [ 6, "" ] ])
    assert_equal 0, @fr.scores.count
  end

  test "only the organizer locks; a locked friendly takes no scores" do
    patch lock_friendly_scores_path(@fr)
    assert_not @fr.reload.scores_locked?

    post session_path, params: { email: @org.email, password: "tennis-123" }
    patch lock_friendly_scores_path(@fr)
    assert @fr.reload.scores_locked?
    save(court: 1, name: "Jen", sets: [ [ 6, 4 ] ])
    assert_equal 0, @fr.scores.count
  end
end
