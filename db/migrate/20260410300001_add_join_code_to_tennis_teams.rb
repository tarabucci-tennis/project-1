class AddJoinCodeToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :join_code, :string
    add_index :tennis_teams, :join_code, unique: true
  end
end
