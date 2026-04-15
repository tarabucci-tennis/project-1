class AddTennislinkTeamIdToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :tennislink_team_id, :string
  end
end
