class NightlySyncJob < ApplicationJob
  queue_as :default

  # Refreshes everything Court Report pulls from public sources, on a
  # schedule, so the site stays current with nobody pressing a button:
  #   * match results + posted lineups, from the Google Sheet
  #   * opponent league standings, from the public tenniscores sites
  #     (Bux-Mont, Del-Tri, Inter-Club / WITAP)
  #   * fixture lists, for teams opted in via schedule_sync
  #   * each rostered player's personal match history
  #   * USTA postseason info, from TennisRecord
  # then recomputes Court Report ratings.
  #
  # Scheduled nightly in config/recurring.yml. Every step is isolated so
  # one league being unreachable doesn't stop the others, and every call
  # here is idempotent and safe to re-run. This mirrors the manual
  # "Sync scores" admin button and the scores:sync rake task.
  def perform
    step("Google Sheet")    { SheetScoreSync.new.call }
    step("Standings")       { DeltriStandings.new.call }
    step("Schedules")       { TenniscoresSchedule.sync_all }
    step("Del-Tri results") { DeltriResults.new.call }
    step("Player history")  { DeltriPlayerImport.sync_all }
    step("Postseason")      { TennisrecordPlayoffs.new.call }
    step("Ratings")         { RatingCalculator.recompute! }
  end

  private

  def step(label)
    yield
    Rails.logger.info("[NightlySync] #{label}: ok")
  rescue StandardError => e
    Rails.logger.error("[NightlySync] #{label} failed: #{e.class} — #{e.message}")
  end
end
