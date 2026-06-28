class AddTenniscoresUrlToTennisTeams < ActiveRecord::Migration[8.1]
  DELTRI = "https://deltri.tenniscores.com/?mod=nndz-TjJiOWtOR3QzTU4yakRrY1NjN1FMcGpx&did=nndz-WXllNndRPT0%3D".freeze
  WITAP  = "https://witap.tenniscores.com/?mod=nndz-TjJiOWtORzkwTlJFb0NVU1NzOD0%3D&team=nndz-WWk2OXg3bz0%3D".freeze

  def up
    add_column :tennis_teams, :tenniscores_url, :string

    # Wire the two teams that have public tenniscores pages. Keyed on league
    # category so it doesn't depend on the exact stored team name.
    say_with_time "Backfilling tenniscores_url" do
      TennisTeam.reset_column_information
      TennisTeam.where(league_category: "Local").update_all(tenniscores_url: DELTRI)
      TennisTeam.where(league_category: "Inter-Club").update_all(tenniscores_url: WITAP)
    end
  end

  def down
    remove_column :tennis_teams, :tenniscores_url
  end
end
