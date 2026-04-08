class AddFieldsToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :league, :string
    add_column :teams, :home_court, :string
    add_column :teams, :join_code, :string
    add_column :teams, :usta_team_number, :string
    add_index :teams, :join_code, unique: true
  end
end
