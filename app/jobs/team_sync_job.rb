# The team page's "Sync scores" button: pull one team's results from its
# league site (Tenniscores: Del-Tri, Bux-Mont, Inter-Club) right now, instead
# of waiting for the hourly sync. Runs in the background; its state is kept in
# the cache so the page can say "Syncing…" and when it last finished.
class TeamSyncJob < ApplicationJob
  queue_as :default

  def self.key(team_id) = "team_sync:#{team_id}"

  def self.status(team_id)
    Rails.cache.read(key(team_id)) || {}
  end

  # A run counts as stuck after 5 minutes, so a crash never blocks the button.
  def self.running?(team_id)
    s = status(team_id)
    s[:state] == "running" && s[:started_at].present? && s[:started_at].to_time > 5.minutes.ago
  end

  def perform(team_id)
    Rails.cache.write(self.class.key(team_id), { state: "running", started_at: Time.current }, expires_in: 1.day)
    result = DeltriResults.new.call(TennisTeam.where(id: team_id))
    Rails.cache.write(self.class.key(team_id),
                      { state: "done", finished_at: Time.current, ok: result.notes.empty? },
                      expires_in: 30.days)
  rescue StandardError => e
    Rails.cache.write(self.class.key(team_id), { state: "done", finished_at: Time.current, ok: false }, expires_in: 30.days)
    Rails.logger.error("TeamSyncJob #{team_id}: #{e.class} #{e.message}")
  end
end
