require "test_helper"

# A stale form security code shows a friendly message, not the bare 422 page
# (Tara, Nov 24 2026).
class StaleFormTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  test "a form with an expired security code sends you back with a plain message" do
    org = User.create!(name: "Stale Org", email: "stale-org@example.com", password: "tennis-123")
    fr = org.organized_friendlies.create!(title: "Stale RR", starts_at: 2.days.from_now, kind: "round_robin")
    post friendly_players_path(fr), params: { name: "Jen", authenticity_token: "expired" },
                                    headers: { "Referer" => friendly_url(fr) }
    assert_redirected_to friendly_url(fr)
    assert_match(/open a while/, flash[:alert])
    assert_equal 0, fr.spots.count
  end
end
