class CreateLineupSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :lineup_slots do |t|
      t.references :scheduled_match, null: false, foreign_key: true
      t.references :team_player, null: false, foreign_key: true
      t.string :position, null: false
      t.timestamps
    end

    add_index :lineup_slots, [ :scheduled_match_id, :position, :team_player_id ], unique: true, name: "idx_lineup_match_position_player"
  end
end
