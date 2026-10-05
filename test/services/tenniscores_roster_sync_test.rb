require "test_helper"

class TenniscoresRosterSyncTest < ActiveSupport::TestCase
  Player = TenniscoresRoster::Player

  setup do
    owner = User.create!(name: "Owner", email: "roster-sync-test@example.com")
    @team = owner.tennis_teams.create!(name: "Sync Team", league_category: "Local",
                                       tenniscores_url: "https://buxmont.tenniscores.com/?team=x")
    @existing = User.create!(name: "Jane Here")
    TeamMembership.create!(user: @existing, tennis_team: @team, role: "player")
    @roster = [
      Player.new(group: "Captains", name: "Cap Person", role: "C", rating: "4.5"),
      Player.new(group: "Players", name: "Jane Here", role: nil, rating: "4.0"),
      Player.new(group: "Players Subbing for this Team", name: "Sub Person", role: nil, rating: "4.0")
    ]
  end

  test "adds site players, marks the captain, skips subs and league ratings" do
    TenniscoresRoster.class_eval { alias_method :__orig_fetch_fresh, :fetch_fresh }
    roster = @roster
    TenniscoresRoster.define_method(:fetch_fresh) { roster }
    result = TenniscoresRosterSync.new.call

    names = @team.team_memberships.active.includes(:user).map { |m| m.user.name }.sort
    assert_equal [ "Cap Person", "Jane Here" ], names
    assert_equal "captain", @team.team_memberships.joins(:user).find_by(users: { name: "Cap Person" }).role
    assert_nil User.find_by(name: "Cap Person").ntrp_rating, "league ratings must not become USTA ratings"
    assert_equal({ "Sync Team" => 1 }, result.added)

    # Running again adds nobody.
    assert_equal({}, TenniscoresRosterSync.new.call.added)
  ensure
    TenniscoresRoster.class_eval do
      alias_method :fetch_fresh, :__orig_fetch_fresh
      remove_method :__orig_fetch_fresh
    end
  end
end
