class CreatePlayerAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :player_availabilities do |t|
      t.references :scheduled_match, null: false, foreign_key: true
      t.references :team_player, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :message
      t.timestamps
    end

    add_index :player_availabilities, [ :scheduled_match_id, :team_player_id ], unique: true, name: "idx_availability_match_player"
  end
end
