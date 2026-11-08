require "test_helper"

# Possible duplicate players on Site members, and sign-up linking a new
# account to the matching roster entry instead of making a second one.
class DuplicatePlayersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Ada Admin", email: "dup-admin@example.com", password: "tennis-123", admin: true)
    @team = TennisTeam.create!(user: @admin, name: "Dup Aces", league_category: "USTA", league_name: "USTA")
  end

  def roster(name)
    u = User.create!(name: name)
    TeamMembership.create!(user: u, tennis_team: @team, role: "player")
    u
  end

  test "finds the same player spelled differently, not different people" do
    roster("Kerry McDuffle"); roster("Kerry McDuffie")
    roster("Jaci Gronen"); roster("Jaclyn Groenen")
    roster("Helen Lee"); roster("Helen He")
    roster("karen ernst"); roster("Karen Ernst")
    pairs = DuplicatePlayers.find.map { |p| [ p.a.name, p.b.name ].sort }
    assert_includes pairs, [ "Kerry McDuffie", "Kerry McDuffle" ]
    assert_includes pairs, [ "Jaci Gronen", "Jaclyn Groenen" ]
    assert_includes pairs, [ "Karen Ernst", "karen ernst" ]
    assert_not_includes pairs, [ "Helen He", "Helen Lee" ]
  end

  test "Site members lists possible duplicates for the admin" do
    roster("Kerry McDuffle"); roster("Kerry McDuffie")
    post session_path, params: { email: @admin.email, password: "tennis-123" }
    get admin_members_path
    assert_select ".cr-dup .cr-dup-row", 1
    assert_select ".cr-dup-row .cr-dup-name", text: "Kerry McDuffle"
    assert_select ".cr-dup-row .cr-dup-reason", text: "Similar name"
  end

  def sign_up(name, email)
    get signup_path
    started = css_select("input[name=form_started]").first["value"]
    travel 10.seconds do
      post signup_path, params: { name: name, email: email, password: "tennis-123",
                                  password_confirmation: "tennis-123", form_started: started }
    end
  end

  test "signing up with a roster entry's exact name claims it" do
    entry = roster("Jody Staples")
    assert_no_difference "User.count" do
      sign_up("jody staples", "jody-real@example.com")
    end
    entry.reload
    assert_equal "jody-real@example.com", entry.email
    assert entry.authenticate("tennis-123")
    assert_includes entry.member_teams, @team
  end

  test "two roster entries with that name: no guessing, a new account" do
    roster("Sam Same"); roster("Sam Same")
    assert_difference "User.count", 1 do
      sign_up("Sam Same", "sam-real@example.com")
    end
  end
end
