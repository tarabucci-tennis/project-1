require "test_helper"

# Beta tag popup + one-time welcome card + admin feedback page (Tara, Nov 24 2026).
class BetaFeedbackTest < ActionDispatch::IntegrationTest
  setup do
    @me = User.create!(name: "Beta Player", email: "beta-player@example.com", password: "tennis-123")
    @admin = User.create!(name: "Beta Admin", email: "beta-admin@example.com", password: "tennis-123", admin: true)
  end

  def sign_in(u) = post(session_path, params: { email: u.email, password: "tennis-123" })

  test "the welcome card shows once; Got it hides it for good" do
    sign_in(@me)
    get teams_path
    assert_select ".cr-beta-welcome", text: /Welcome to the Court Report beta/
    assert_select "button.cr-beta-pill[popovertarget=cr-beta-pop]"
    patch beta_welcomed_path
    assert @me.reload.beta_welcomed_at
    get teams_path
    assert_select ".cr-beta-welcome", count: 0
  end

  test "players and guests can send feedback; only admins read it" do
    sign_in(@me)
    post feedback_path, params: { message: "Love the round robins!" }, headers: { "Referer" => "http://www.example.com/friendlies" }
    fb = Feedback.last
    assert_equal @me, fb.user
    assert_equal "/friendlies", fb.page
    assert @me.reload.beta_welcomed_at, "sending feedback also closes the welcome card"

    post feedback_path, params: { message: "  " }
    assert_equal 1, Feedback.count

    get admin_feedback_path
    assert_redirected_to root_path

    delete session_path
    post feedback_path, params: { message: "Guest idea", name: "Pat" }
    assert_equal "Pat", Feedback.last.from_label

    sign_in(@admin)
    get admin_feedback_path
    assert_select ".cr-fb-item", 2
    assert_match(/Love the round robins!/, response.body)
  end

  test "the public home page has the tappable Beta tag too" do
    get root_path
    assert_select "button.cr-beta-pill[popovertarget=cr-beta-pop]"
    assert_select "#cr-beta-pop textarea[name=message]"
  end
end
