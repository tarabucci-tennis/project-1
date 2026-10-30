require "test_helper"

# An admin can remove a junk account straight from its player page.
class AdminRemoveAccountTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Ada Admin", email: "remove-admin@example.com", password: "tennis-123", admin: true)
    @spam = User.create!(name: "Spam Account", email: "spam@example.com")
    @player = User.create!(name: "Pat Player", email: "remove-player@example.com", password: "tennis-123")
  end

  test "an admin sees Remove on someone else's page and lands back on Site members" do
    post session_path, params: { email: @admin.email, password: "tennis-123" }
    get player_path(@spam)
    assert_select "button", text: "Remove this account"
    get player_path(@admin)
    assert_select "button", text: "Remove this account", count: 0

    assert_difference "User.count", -1 do
      delete user_path(@spam, return_to: "members")
    end
    assert_redirected_to admin_members_path
  end

  test "Site members has Remove next to every name except the admin's own" do
    post session_path, params: { email: @admin.email, password: "tennis-123" }
    get admin_members_path
    assert_response :success
    assert_select "form.cr-mem-remove-form[action=?]", user_path(@player, return_to: "members")
    assert_select "form.cr-mem-remove-form[action=?]", user_path(@admin, return_to: "members"), count: 0
  end

  test "an admin can set a player's USTA rating from Site members" do
    post session_path, params: { email: @admin.email, password: "tennis-123" }
    get edit_user_path(@player, return_to: "members")
    assert_select "select[name=?]", "user[ntrp_rating]"
    patch user_path(@player, return_to: "members"), params: { user: { name: @player.name, ntrp_rating: "4.0" } }
    assert_redirected_to admin_members_path
    assert_equal 4.0, @player.reload.ntrp_rating.to_f
    patch user_path(@player), params: { user: { name: @player.name, ntrp_rating: "" } }
    assert_nil @player.reload.ntrp_rating
  end

  test "a regular player never sees it" do
    post session_path, params: { email: @player.email, password: "tennis-123" }
    get player_path(@spam)
    assert_select "button", text: "Remove this account", count: 0
  end
end
