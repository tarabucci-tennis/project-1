class CreateDivisionTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :division_teams do |t|
      t.references :tennis_team, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :wins, default: 0, null: false
      t.integer :losses, default: 0, null: false
      t.integer :position  # rank in standings
      t.timestamps
    end

    add_index :division_teams, [:tennis_team_id, :name], unique: true
  end
end
