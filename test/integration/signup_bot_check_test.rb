require "test_helper"

# Sign-up stops bots without bothering people: a hidden box only bots fill
# in, a minimum time on the form, and no links or symbols in the name.
class SignupBotCheckTest < ActionDispatch::IntegrationTest
  def form_started
    get signup_path
    css_select("input[name=form_started]").first["value"]
  end

  def sign_up(name: "Jane Smith", email: "jane-signup@example.com", **extra)
    post signup_path, params: { name: name, email: email, password: "tennis-123",
                                password_confirmation: "tennis-123" }.merge(extra)
  end

  test "a real person who takes a few seconds can sign up" do
    started = form_started
    travel 10.seconds do
      assert_difference "User.count", 1 do
        sign_up(form_started: started)
      end
    end
    assert_redirected_to root_path
  end

  test "a form sent back instantly, or without its start time, is refused" do
    started = form_started
    assert_no_difference "User.count" do
      sign_up(form_started: started)
      sign_up
      sign_up(form_started: "made-up")
    end
    assert_response :unprocessable_entity
    assert_match "Please press Sign Up again", response.body
  end

  test "filling in the hidden box is refused" do
    started = form_started
    travel 10.seconds do
      assert_no_difference "User.count" do
        sign_up(form_started: started, cr_contact_me: "http://spam.example")
      end
    end
  end

  test "a name with a link, money or long numbers is refused" do
    started = form_started
    travel 10.seconds do
      [ "Payment available $3,222 http://x.co", "Win big at site.com", "Promo 12345" ].each do |spam|
        assert_no_difference "User.count" do
          sign_up(name: spam, form_started: started)
        end
        assert_match "Please enter just your name", response.body
      end
      assert_difference "User.count", 1 do
        sign_up(name: "Mary-Jo O'Neil", form_started: started)
      end
    end
  end
end
