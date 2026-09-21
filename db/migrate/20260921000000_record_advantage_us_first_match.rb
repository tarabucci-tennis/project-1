# Records Advantage Us's first Bux-Mont match: 09/14/2026 vs Upper Dublin
# Orchids, a 2-4 loss (41-63 games), with all six line results. Data verified
# against the league's published standings (2 line wins, 63 games lost).
#
# Bux-Mont is timed play, so partial-set scores (5-5, 4-3, 6-6) are normal, and
# the line goes to the pair with the most TOTAL games, not the most sets.
#
# Idempotent: finds-or-creates the team, the match, and each player; skips the
# line results if the match already has them, and only sets the match result
# when it is blank.
class RecordAdvantageUsFirstMatch < ActiveRecord::Migration[8.1]
  TEAM_URL = "https://buxmont.tenniscores.com/?mod=nndz-TjJiOWtORzkwTlJFb0NVU1NzOD0%3D&team=nndz-WkNDN3hMbnc%3D".freeze

  # our pair, set scores (Advantage Us games first), per-line result
  LINES = [
    { pos: 1, players: [ "Alice Kellepourey", "Rachel Chadwin" ],     s1: "1-6", s2: "4-6", s3: "0-1", result: "loss" },
    { pos: 2, players: [ "Nicole Costelloe", "Jaclyn Groenen" ],      s1: "6-4", s2: "6-2", s3: nil,  result: "win" },
    { pos: 3, players: [ "Lynn Sundblad", "Christina Faidley" ],      s1: "6-2", s2: "0-6", s3: nil,  result: "loss" },
    { pos: 4, players: [ "Jody Staples", "Rachel Miller" ],           s1: "2-6", s2: "3-5", s3: nil,  result: "loss" },
    { pos: 5, players: [ "Carolyn Melzer", "Rebecca Feinberg" ],      s1: "6-6", s2: "4-2", s3: nil,  result: "win" },
    { pos: 6, players: [ "Regina Antinori", "Patti Zarkoski" ],       s1: "2-6", s2: "0-6", s3: "1-5", result: "loss" }
  ].freeze

  def up
    tara = User.find_by(email: "tarabucci@gmail.com") || User.find_by("LOWER(name) = ?", "tara bucci")
    return unless tara

    team = TennisTeam.find_or_initialize_by(name: "Advantage Us")
    team.assign_attributes(
      user:            team.user || tara,
      league_category: "Local",
      league_name:     "Bux-Mont",
      standings_style: "win_loss",
      tenniscores_url: (team.tenniscores_url.presence || TEAM_URL),
      schedule_sync:   true,
      season_name:     (team.season_name.presence || "2026-27"),
      start_date:      (team.start_date || Date.new(2026, 9, 14)),
      team_type:       (team.team_type.presence || "Monday Tennis · Division 1"),
      gender:          (team.gender.presence || "Women's"),
      section:         (team.section.presence || "Bux-Mont Tennis League")
    )
    team.save!

    TeamMembership.find_or_create_by!(user: tara, tennis_team: team, archived_season: nil)

    date = Time.zone.local(2026, 9, 14, 19, 0)
    match = team.matches.where(match_date: date.all_day)
                .where("LOWER(opponent) = ?", "upper dublin orchids").first
    match ||= team.matches.new(match_date: date, opponent: "Upper Dublin Orchids")
    match.assign_attributes(home_away: "home", location: team.home_court.presence)
    match.result = "loss" if match.result.blank?
    match.score_summary = "2-4" if match.score_summary.blank?
    match.save!

    return if match.match_lines.exists?

    LINES.each do |ln|
      line = match.match_lines.create!(
        line_type: "doubles", position: ln[:pos],
        set1_score: ln[:s1], set2_score: ln[:s2], set3_score: ln[:s3],
        result: ln[:result]
      )
      ln[:players].each do |name|
        user = User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
        line.match_line_players.create!(user: user)
      end
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
