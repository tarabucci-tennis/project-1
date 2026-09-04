# Sets up Tara's Bux-Mont team (Advantage Us, Monday Tennis Division 1) and
# pulls its schedule and division standings from the public league site.
#
#   docker exec project-1 bin/rails buxmont:setup
#
# Safe to re-run: the team, the membership and every match are matched on
# identity, not recreated, and a match that already has a result entered is
# left alone.
namespace :buxmont do
  TEAM_NAME = "Advantage Us".freeze

  # The team's own page on the league site. It carries both the Division 1
  # standings table and this team's 27-row schedule, so one link drives both
  # importers. Note there is deliberately no `did=` param — adding one makes
  # the site ignore `team=` and render the first team in the division instead.
  TEAM_URL = "https://buxmont.tenniscores.com/?mod=nndz-TjJiOWtORzkwTlJFb0NVU1NzOD0%3D&team=nndz-WkNDN3hMbnc%3D".freeze

  desc "Create/refresh Tara's Bux-Mont team and pull its schedule + standings"
  task setup: :environment do
    tara = User.find_by(email: "tarabucci@gmail.com") || User.find_by("LOWER(name) = ?", "tara bucci")
    abort "Couldn't find Tara's user record — set it up on /users first." unless tara

    team = TennisTeam.find_or_initialize_by(name: TEAM_NAME)
    team.assign_attributes(
      user:             team.user || tara,
      league_category:  "Local",
      league_name:      "Bux-Mont",
      standings_style:  "win_loss",
      tenniscores_url:  TEAM_URL,
      schedule_sync:    true,
      season_name:      "2026-27",
      start_date:       Date.new(2026, 9, 14),
      team_type:        "Monday Tennis · Division 1",
      gender:           "Women's",
      section:          "Bux-Mont Tennis League"
    )
    team.save!
    puts "Team: #{team.name} (##{team.id}) — #{team.league_label}"

    membership = TeamMembership.find_or_initialize_by(user: tara, tennis_team: team, archived_season: nil)
    membership.save!
    puts "Roster: #{team.team_memberships.active.count} player(s) — add the rest on the team's Roster tab."

    puts "Schedule: #{TenniscoresSchedule.new(team.reload).call}"
    puts "Standings: #{DeltriStandings.new.call}"
  end
end
