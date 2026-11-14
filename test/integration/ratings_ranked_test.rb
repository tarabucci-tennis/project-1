require "test_helper"

class RatingsRankedTest < ActionDispatch::IntegrationTest
  def summary(name, wins, losses)
    RatingsHistory::PlayerSummary.new(name: name, wins: wins, losses: losses)
  end

  test "ranks by win %, and players under 5 lines go last unranked" do
    rows = RatingsHistory.rank([ summary("Tara", 11, 6), summary("Newbie", 2, 0),
                                 summary("Jody", 10, 3), summary("Jaci", 10, 9) ])
    assert_equal %w[Jody Tara Jaci Newbie], rows.map(&:name)
    assert_not rows.last.ranked?
  end

  test "Teams tab lists each of my USTA teams with its roster ranked" do
    admin = User.create!(name: "Rank Admin", email: "rank-admin@example.com", password: "tennis-123", admin: true)
    mate = User.create!(name: "Rank Mate", email: "rank-mate@example.com")
    team = TennisTeam.create!(name: "Rank Aces", league_category: "USTA", user: admin)
    TeamMembership.create!(user: admin, tennis_team: team, role: "captain")
    TeamMembership.create!(user: mate, tennis_team: team, role: "player")
    TennisTeam.create!(name: "Not Mine", league_category: "USTA", user: mate)

    fake = [ summary("Rank Mate", 8, 2), summary("Rank Admin", 6, 4), summary("Stranger", 1, 0) ]
    original = RatingsHistory.method(:player_summaries)
    RatingsHistory.define_singleton_method(:player_summaries) { |*| fake }
    begin
      post session_path, params: { email: admin.email, password: "tennis-123" }
      get ratings_path
    ensure
      RatingsHistory.define_singleton_method(:player_summaries, original)
    end
    assert_response :success
    assert_select ".cr-rp-tabs .cr-home-tab", text: "All players"
    assert_select ".cr-rp-tabs .cr-home-tab", text: "Teams"
    assert_select ".cr-rp-panel-players tbody tr", 3
    assert_select ".cr-rp-panel-players tbody tr:first-child td", text: "Rank Mate"
    assert_select ".cr-rp-panel-teams details.cr-rp-team", 1
    assert_select ".cr-rp-team summary", text: /Rank Aces/
    assert_select ".cr-rp-team tbody tr", 2
    assert_select ".cr-rp-team tbody tr:first-child .cr-rp-rank", text: "1"
    assert_select ".cr-rp-team tbody tr:first-child td", text: "Rank Mate"
  end
end
