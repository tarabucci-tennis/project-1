# Links Legacy 1 (Del-Tri Division 1) to its public Tenniscores team page so
# the nightly sync pulls its line-by-line results, the Division 1 standings,
# and each rostered player's match history — the same as Advantage Us.
#
# schedule_sync is deliberately left off: the 18-match schedule was already
# imported from the team's .ics export and checked; the nightly results import
# still creates any match it finds that's missing.
#
# Only fills the link if it's blank, so a link set by hand is never replaced.
class AddLegacy1TenniscoresUrl < ActiveRecord::Migration[8.1]
  URL = "https://deltri.tenniscores.com/?mod=nndz-TjJiOWtORzkwTlJFb0NVU1NzOD0%3D&team=nndz-WnllK3lMOD0%3D".freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "legacy 1").first
    return unless team
    return if team.tenniscores_url.present?

    team.update_columns(tenniscores_url: URL)
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
