require "test_helper"

# QA qa-168: /create-team has a plain Cancel link back to My Teams; it saves nothing.
class CreateTeamCancelTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Cancel Me", email: "cancel-me@example.com", password: "tennis-123")
    post session_path, params: { email: @me.email, password: "tennis-123" }
  end

  test "Create a Team has a Cancel link to My Teams, outside the submit" do
    get new_team_path
    assert_select "form p.cr-form-cancel a[href=?]", teams_path, text: "Cancel"
    assert_no_difference("TennisTeam.count") { get teams_path }
    assert_response :success
  end
end
