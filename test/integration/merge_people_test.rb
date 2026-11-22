require "test_helper"

class MergePeopleTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Merge Admin", email: "merge-admin@example.com", password: "tennis-123", admin: true)
    @team = TennisTeam.create!(user: @admin, name: "Merge PCC", league_category: "Inter-Club", league_name: "Inter-Club")
    @other_team = TennisTeam.create!(user: @admin, name: "Merge Legacy", league_category: "Local", league_name: "Del-Tri")
    @partner = User.create!(name: "Merge Partner", email: "merge-partner@example.com")
  end

  def lines_for(user, team, wins, total)
    total.times do |i|
      m = team.matches.create!(opponent: "Opp #{user.id}-#{i}", match_date: (40 - i).days.ago)
      line = m.match_lines.create!(line_type: "doubles", position: 1, result: i < wins ? "win" : "loss", set1_score: "6-4")
      line.match_line_players.create!(user: user)
      line.match_line_players.create!(user: @partner)
    end
  end

  test "finds same-name and nearly-same-name pairs, not different people" do
    a = User.create!(name: "Joanne Steinberg")
    b = User.create!(name: "JoAnne Steinberg")
    c = User.create!(name: "Kriste Davidse")
    d = User.create!(name: "Kristen Davidse")
    e = User.create!(name: "Sarah Dougherty")
    f = User.create!(name: "Sarah  Dougherty ")
    User.create!(name: "Helen Lee")
    User.create!(name: "Helen He")
    User.create!(name: "Tara Buchakjian")
    pairs = DuplicatePeople.pairs.map { |p| [ p.a.id, p.b.id ].sort }
    assert_includes pairs, [ a.id, b.id ].sort
    assert_includes pairs, [ c.id, d.id ].sort
    assert_includes pairs, [ e.id, f.id ].sort
    names = DuplicatePeople.pairs.flat_map { |p| [ p.a.name, p.b.name ] }
    assert_not_includes names, "Helen He"
    assert_not_includes names, "Tara Buchakjian"
  end

  test "merging Joanne + JoAnne gives one person with 5 of 12, on each team once" do
    joanne = User.create!(name: "Joanne Steinberg")                                     # roster placeholder
    joAnne = User.create!(name: "JoAnne Steinberg", email: "joanne@example.com", password: "tennis-123")
    TeamMembership.create!(user: joanne, tennis_team: @team, role: "player")
    TeamMembership.create!(user: joAnne, tennis_team: @team, role: "captain")
    TeamMembership.create!(user: joanne, tennis_team: @other_team, role: "player")
    lines_for(joanne, @team, 1, 2)
    lines_for(joAnne, @other_team, 4, 10)
    joanne.player_matches.create!(source: "witap", source_key: "k1", league: "Inter-Club", result: "win", played_on: Date.new(2026, 5, 5))

    post session_path, params: { email: @admin.email, password: "tennis-123" }
    get admin_duplicates_path
    assert_response :success
    assert_select ".cr-dup", text: /Joanne Steinberg/

    assert_difference -> { User.count } => -1 do
      post admin_merge_path, params: { a_id: joanne.id, b_id: joAnne.id, keep_name: "JoAnne Steinberg" }
    end
    assert_redirected_to admin_duplicates_path
    assert_not User.exists?(joanne.id)
    kept = joAnne.reload
    assert_equal "JoAnne Steinberg", kept.name
    assert_equal "joanne@example.com", kept.email
    assert_equal 12, PlayerRecord.new(kept).court_report_entries.size
    assert_equal 5, PlayerRecord.new(kept).court_report_entries.count(&:won?)
    assert_equal 1, kept.player_matches.count
    assert_equal 1, kept.team_memberships.where(tennis_team: @team).count
    assert_equal "captain", kept.team_memberships.find_by(tennis_team: @team).role
    assert_equal 1, kept.team_memberships.where(tennis_team: @other_team).count
  end

  test "two records that can both sign in are not merged" do
    a = User.create!(name: "Sarah Dougherty", email: "s1@example.com")
    b = User.create!(name: "Sarah Dougherty", email: "s2@example.com")
    post session_path, params: { email: @admin.email, password: "tennis-123" }
    assert_no_difference -> { User.count } do
      post admin_merge_path, params: { a_id: a.id, b_id: b.id, keep_name: "Sarah Dougherty" }
    end
    assert_match(/Both have their own sign-in/, flash[:alert])
  end

  test "only admins can see or merge" do
    player = User.create!(name: "Merge Player", email: "merge-player@example.com", password: "tennis-123")
    a = User.create!(name: "Dup One")
    b = User.create!(name: "Dup  One")
    post session_path, params: { email: player.email, password: "tennis-123" }
    get admin_duplicates_path
    assert_response :redirect
    assert_no_difference -> { User.count } do
      post admin_merge_path, params: { a_id: a.id, b_id: b.id, keep_name: "Dup One" }
    end
  end
end

class MergeFollowupTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Follow Admin", email: "follow-admin@example.com", password: "tennis-123", admin: true)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "tennis-123" }
  end

  test "partner table groups a league-website spelling with the Court Report player" do
    tara = User.create!(name: "Follow Tara", email: "follow-tara@example.com", password: "tennis-123")
    jo = User.create!(name: "JoAnne Follow")
    team = TennisTeam.create!(user: tara, name: "Follow PCC", league_category: "Inter-Club", league_name: "Inter-Club")
    3.times do |i|
      m = team.matches.create!(opponent: "Opp #{i}", match_date: (30 - i).days.ago)
      l = m.match_lines.create!(line_type: "doubles", position: 1, result: "win", set1_score: "6-1")
      l.match_line_players.create!(user: tara)
      l.match_line_players.create!(user: jo)
    end
    tara.player_matches.create!(source: "deltri", source_key: "p1", league: "Del-Tri", played_on: 5.days.ago.to_date,
                                result: "loss", partner: "Joanne  Follow", match_label: "Legacy 1 vs DVTA")
    sign_in(tara)
    get profile_path
    assert_select ".cr-playing-stats-row", text: /JoAnne Follow\s*75%\s*3–1 \(4 matches\)/
    assert_select ".cr-playing-stats-row", text: /Joanne  Follow/, count: 0
  end

  test "an old profile link forwards to the record it was merged into" do
    old = User.create!(name: "Fwd Joanne")
    kept = User.create!(name: "Fwd JoAnne", email: "fwd@example.com")
    old_id = old.id
    UserMerge.new(old, kept, name: "Fwd JoAnne").call
    assert_equal kept.id, MergedUser.current_id_for(old_id)

    sign_in(@admin)
    get player_path(old_id)
    assert_redirected_to player_path(kept)
    get player_path(999_999)
    assert_redirected_to teams_path
  end

  test "admin can save a rating date; the profile shows it" do
    sarah = User.create!(name: "Date Sarah", email: "date-sarah@example.com", ntrp_rating: 3.0)
    sign_in(@admin)
    patch user_path(sarah, return_to: "members"),
          params: { user: { name: sarah.name, ntrp_rating: "3.0", ntrp_rating_date: "2025-12-31" } }
    assert_equal Date.new(2025, 12, 31), sarah.reload.ntrp_rating_date
    get player_path(sarah)
    assert_select ".cr-pp-metric-cap", text: /year-end 2025/
  end
end

class TaraConfirmedFixesNov17Test < ActiveSupport::TestCase
  def run_update
    require Rails.root.join("db/migrate/20261117150000_tara_confirmed_fixes_nov_17").to_s
    ActiveRecord::Migration.suppress_messages { TaraConfirmedFixesNov17.new.up }
  end

  test "both Davidse records can sign in: keeps the recent login, merges into Kristen Davidse" do
    old = User.create!(name: "Kriste Davidse", email: "kd-old@example.com", password: "tennis-123", last_sign_in_at: 3.months.ago)
    used = User.create!(name: "Kristen Davidse", email: "kd-new@example.com", password: "tennis-123", last_sign_in_at: 1.day.ago)
    team = TennisTeam.create!(user: used, name: "KD Team", league_category: "Local", league_name: "Bux-Mont")
    TeamMembership.create!(user: old, tennis_team: team, role: "player")
    run_update
    assert_not User.exists?(old.id)
    used.reload
    assert_equal "Kristen Davidse", used.name
    assert_equal "kd-new@example.com", used.email
    assert_equal 1, used.team_memberships.count
    assert_equal used.id, MergedUser.current_id_for(old.id)
    assert_no_difference -> { User.count } do
      run_update
    end
  end

  test "Sarah's blank rating date becomes 12/31/2025; Tri Hards is archived" do
    sarah = User.create!(name: "Sarah Dougherty", ntrp_rating: 3.0)
    tri = TennisTeam.create!(user: sarah, name: "Tri Hards", league_category: "USTA")
    run_update
    assert_equal Date.new(2025, 12, 31), sarah.reload.ntrp_rating_date
    assert tri.reload.archived?
  end
end
