# Refreshes everything Court Report pulls from public sources:
#   * match results + posted lineups, from Tara's Google Sheet
#   * opponent league standings, from the public tenniscores sites
#   * fixture lists, for teams opted in via schedule_sync (Bux-Mont)
#
# Designed to be run on a schedule (hourly cron) so the site stays current
# with no button-clicking:
#
#   0 * * * * docker exec project-1 bin/rails scores:sync >> /var/log/cr-sync.log 2>&1
#
# Both steps are idempotent and safe to re-run.
namespace :scores do
  desc "Pull latest scores (Google Sheet) and standings (Del-Tri) from public sources"
  task sync: :environment do
    stamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")

    sheet = SheetScoreSync.new.call
    puts "[#{stamp}] Scores — #{sheet}"

    standings = DeltriStandings.new.call
    puts "[#{stamp}] Standings — #{standings}"

    schedules = TenniscoresSchedule.sync_all
    puts "[#{stamp}] Schedules — #{schedules}"

    deltri = DeltriResults.new.call
    puts "[#{stamp}] Del-Tri results — #{deltri}"

    players = DeltriPlayerImport.sync_all
    puts "[#{stamp}] Del-Tri player history — #{players}"

    playoffs = TennisrecordPlayoffs.new.call
    puts "[#{stamp}] Postseason (TennisRecord) — #{playoffs}"

    RatingCalculator.recompute!
    puts "[#{stamp}] Court Report ratings recomputed"
  end
end
