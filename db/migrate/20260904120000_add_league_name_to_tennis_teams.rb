# Bux-Mont is the fourth league Tara plays in, and the second one that lives
# on tenniscores. Until now "Local" was hardwired to mean Del-Tri in the UI,
# so a second local league would have shown up mislabelled.
#
#   league_name      — the league's real name, used for the My Teams tabs and
#                      card labels ("Del-Tri", "Bux-Mont", "USTA Middle States").
#                      Nil falls back to the generic league_category label.
#   schedule_sync    — opt in to pulling the fixture list from that page. Off by
#                      default: Legacy 2 and PCC already have hand-entered
#                      schedules and results, and a scraper must not go near
#                      them until each has been verified against its own site.
#   standings_style  — how that league's table is scored, so the Standings tab
#                      doesn't have to infer it from league_category:
#                      "points"   — Del-Tri / Inter-Club (total games won)
#                      "win_loss" — Bux-Mont (W/L/T + line wins + games lost)
#                      "usta"     — TennisLink layout (sets/games/percentages)
#
# division_teams.ties backs the T column in a W/L/T table.
class AddLeagueNameToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :league_name, :string
    add_column :tennis_teams, :standings_style, :string
    add_column :tennis_teams, :schedule_sync, :boolean, default: false, null: false
    add_column :division_teams, :ties, :integer, default: 0, null: false

    # Backfill so nothing changes name on deploy. Until now the UI printed
    # "Del-Tri" for anything in the Local category; make that explicit rather
    # than letting those teams fall back to the generic "Local Leagues".
    up_only do
      execute <<~SQL
        UPDATE tennis_teams
           SET league_name = 'Del-Tri', standings_style = 'points'
         WHERE league_category = 'Local'
      SQL
      execute <<~SQL
        UPDATE tennis_teams
           SET standings_style = 'points'
         WHERE league_category = 'Inter-Club'
      SQL
      execute <<~SQL
        UPDATE tennis_teams
           SET standings_style = 'usta'
         WHERE league_category = 'USTA'
      SQL
    end
  end
end
