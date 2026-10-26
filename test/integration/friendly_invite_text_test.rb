require "test_helper"

# One "Invite players" button; its text says the same link stays up to date.
class FriendlyInviteTextTest < ActionDispatch::IntegrationTest
  test "the invite asks people to add their name and says the link stays current" do
    organizer = User.create!(name: "Invite Host", email: "fr-invite@example.com", password: "tennis-123")
    friendly = organizer.organized_friendlies.create!(starts_at: 2.days.from_now, title: "After Clinic")

    get friendly_path(friendly)
    button = css_select("button.cr-chip-btn").find { |b| b.text.include?("Invite players") }
    assert button, "Invite players button"
    assert_includes button["data-share-text"], "Can you play? Add your name here."
    assert_includes button["data-share-text"], "This link always shows who's playing and the lineup:"
  end
end
