class AddTennislinkStandingsUrlToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :tennislink_standings_url, :string
  end
end
