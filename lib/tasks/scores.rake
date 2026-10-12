# Refreshes everything Court Report pulls from public sources (Google Sheet,
# tenniscores standings / schedules / rosters / results, player history,
# TennisRecord postseason, ratings). Runs on the droplet every hour:
#
#   0 * * * * docker exec project-1 bin/rails scores:sync >> /var/log/cr-sync.log 2>&1
#
# It runs the same NightlySyncJob as the admin "Sync scores" button, so each
# step is isolated (one league failing doesn't stop the rest) and the admin
# menu's "Last sync" line reflects these hourly runs too.
namespace :scores do
  desc "Pull the latest scores, standings, rosters and results from every league"
  task sync: :environment do
    NightlySyncJob.perform_now
    status = NightlySyncJob.status || {}
    stamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
    Array(status[:steps]).each do |st|
      puts "[#{stamp}] #{st[:label]} — #{st[:ok] ? 'ok' : "FAILED: #{st[:error]}"}"
    end
  end
end
