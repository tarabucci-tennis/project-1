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
  # here is idempotent and safe to re-run. The admin "Sync scores" button
  # queues this same job in the background (running it inside the page
  # request took minutes and the page timed out).
  STATUS_KEY = "nightly_sync:status".freeze

  # What the last run did, for the admin menu: { state:, started_at:,
  # finished_at:, steps: [ { label:, ok:, error: } ] }. Nil if never run since
  # the cache was last cleared.
  def self.status
    Rails.cache.read(STATUS_KEY)
  end

  def self.running?
    s = status
    s.present? && s[:state] == "running" && s[:started_at].to_time > 30.minutes.ago
  end

  def perform
    @steps = []
    save_status("running", started_at: Time.current)
    step("Google Sheet")    { SheetScoreSync.new.call }
    step("Standings")       { DeltriStandings.new.call }
    step("Schedules")       { TenniscoresSchedule.sync_all }
    step("Rosters")         { TenniscoresRosterSync.new.call }
    step("Del-Tri results") { DeltriResults.new.call }
    step("Player history")  { DeltriPlayerImport.sync_all }
    step("Postseason")      { TennisrecordPlayoffs.new.call }
    step("Ratings")         { RatingCalculator.recompute! }
    save_status("done", finished_at: Time.current)
  end

  private

  def step(label)
    yield
    @steps << { label: label, ok: true }
    Rails.logger.info("[NightlySync] #{label}: ok")
  rescue StandardError => e
    @steps << { label: label, ok: false, error: e.message.to_s.truncate(200) }
    Rails.logger.error("[NightlySync] #{label} failed: #{e.class} — #{e.message}")
  ensure
    save_status("running") if @steps.any?
  end

  def save_status(state, **times)
    previous = self.class.status || {}
    previous = {} if state == "running" && times.key?(:started_at)
    Rails.cache.write(STATUS_KEY, previous.merge(times).merge(state: state, steps: @steps.dup), expires_in: 14.days)
  end
end
