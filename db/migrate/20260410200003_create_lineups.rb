class CreateLineups < ActiveRecord::Migration[8.1]
  def change
    create_table :lineups do |t|
      t.references :match, null: false, foreign_key: true
      t.boolean :published, default: false, null: false
      t.datetime :published_at
      t.timestamps
    end

    create_table :lineup_slots do |t|
      t.references :lineup, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :line_type, null: false     # "singles" or "doubles"
      t.integer :position, null: false      # 1, 2, 3, 4, 5
      t.string :confirmation, default: "pending", null: false  # pending, confirmed, declined
      t.datetime :confirmed_at
      t.timestamps
    end

    add_index :lineups, [:match_id], unique: true
    add_index :lineup_slots, [:lineup_id, :user_id], unique: true
  end
end
