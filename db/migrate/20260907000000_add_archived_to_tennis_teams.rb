class AddArchivedToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :archived, :boolean, default: false, null: false
    add_index :tennis_teams, :archived
  end
end
