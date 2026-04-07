class CreateTeamPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :team_players do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :player_name, null: false
      t.string :role, default: "player", null: false
      t.timestamps
    end

    add_index :team_players, [ :team_id, :player_name ], unique: true
  end
end
