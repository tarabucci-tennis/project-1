require "test_helper"

# Signing up with the exact name of a roster entry that has never signed in
# links the new account to it, so her teams, lineups and scores come with her.
class SignupClaimsRosterTest < ActionDispatch::IntegrationTest
  setup do
    owner = User.create!(name: "Ada Owner", email: "claim-owner@example.com", password: "tennis-123")
    @team = TennisTeam.create!(user: owner, name: "Claim Aces", league_category: "USTA", league_name: "USTA")
  end

  def roster(name)
    u = User.create!(name: name)
    TeamMembership.create!(user: u, tennis_team: @team, role: "player")
    u
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
