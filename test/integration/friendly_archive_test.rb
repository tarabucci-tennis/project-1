require "test_helper"

# Archive friendlies (Tara, Nov 23 2026): hidden from every list, never deleted,
# restorable. Only the organizer (or an admin) can archive.
class FriendlyArchiveTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Arch Organizer", email: "arch-org@example.com", password: "tennis-123")
    @other = User.create!(name: "Arch Other", email: "arch-other@example.com", password: "tennis-123")
    @past = @me.organized_friendlies.create!(title: "Arch Past Friendly", starts_at: 3.days.ago.change(hour: 9), ends_at: 3.days.ago.change(hour: 10))
    @soon = @me.organized_friendlies.create!(title: "Arch Soon Friendly", starts_at: 2.days.from_now.change(hour: 9), ends_at: 2.days.from_now.change(hour: 10))
    @theirs = @other.organized_friendlies.create!(title: "Arch Their Friendly", starts_at: 4.days.from_now.change(hour: 9), ends_at: 4.days.from_now.change(hour: 10))
    @theirs.spots.create!(user: @me, name: @me.name)
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "archiving one hides it from the lists and keeps it; restore brings it back" do
    patch archive_friendly_path(@soon)
    assert @soon.reload.archived?
    get friendlies_path
    assert_select ".cr-band-card", text: /Arch Soon Friendly/, count: 0
    assert_select ".cr-fr-archived", text: /Arch Soon Friendly/
    get teams_path(tab: "upcoming")
    assert_no_match(/Arch Soon Friendly/, response.body)

    patch archive_friendly_path(@soon)
    assert_not @soon.reload.archived?
    get friendlies_path
    assert_select ".cr-band-card", text: /Arch Soon Friendly/
  end

  test "archive all archives only the friendlies I booked" do
    get friendlies_path
    assert_select "form[action='#{archive_all_friendlies_path}'] button", text: /\(2\)/
    patch archive_all_friendlies_path
    assert @past.reload.archived?
    assert @soon.reload.archived?
    assert_not @theirs.reload.archived?
    assert_equal 3, Friendly.where(title: [ "Arch Past Friendly", "Arch Soon Friendly", "Arch Their Friendly" ]).count
  end

  test "a player can't archive someone else's friendly" do
    patch archive_friendly_path(@theirs)
    assert_not @theirs.reload.archived?
  end
end
