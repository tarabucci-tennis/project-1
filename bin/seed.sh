#!/bin/bash
# Manual database reseed — run this only when you explicitly want to
# reset the four seeded teams (Kiss My Ace, Pour Decisions, Philadelphia
# Country #2, Legacy 2) and their canonical rosters, matches, and
# lineups.
#
# WARNING: db/seeds.rb is DESTRUCTIVE. It runs destroy_all on:
#   - team_memberships for those four teams
#   - team_events for those four teams
#   - the four tennis_teams rows themselves (which cascades to matches,
#     lineups, lineup_slots, match_lines, match_line_players,
#     availabilities, and notifications)
#
# That means anyone who signed up via a join link and got added to one
# of those teams will have their team_membership wiped. User rows are
# preserved (so passwords and emails are kept), but they'll have to
# re-join the team.
#
# Typical reasons to run this:
#   - You just set up the droplet for the first time and want the
#     canonical starting data
#   - You intentionally want to blow away all teammate progress and
#     start fresh (rarely)
#
# DO NOT put this script in bin/auto-deploy.sh or bin/force-deploy.sh.
# It runs exclusively by hand.
#
# Usage on the droplet:
#   bash /root/app/bin/seed.sh

set -e

LOG_PREFIX="[$(date '+%H:%M:%S')]"

echo "$LOG_PREFIX =============================="
echo "$LOG_PREFIX MANUAL DB RESEED"
echo "$LOG_PREFIX This will wipe and recreate the four seeded teams."
echo "$LOG_PREFIX User accounts, passwords, and emails are preserved,"
echo "$LOG_PREFIX but teammates will have to re-join via the join link."
echo "$LOG_PREFIX =============================="

read -p "Are you sure? Type YES to continue: " confirmation
if [ "$confirmation" != "YES" ]; then
  echo "$LOG_PREFIX Cancelled."
  exit 0
fi

echo "$LOG_PREFIX Running db:seed..."
docker exec project-1 bin/rails db:seed

echo "$LOG_PREFIX =============================="
echo "$LOG_PREFIX RESEED COMPLETE"
echo "$LOG_PREFIX =============================="
