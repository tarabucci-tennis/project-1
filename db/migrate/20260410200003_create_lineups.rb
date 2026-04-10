class CreateLineups < ActiveRecord::Migration[8.1]
  def change
    # Drop broken tables from previous partial runs
    drop_table :lineup_slots if table_exists?(:lineup_slots)
    drop_table :lineups if table_exists?(:lineups)

    create_table :lineups do |t|
      t.references :match, null: false, foreign_key: true
      t.boolean :published, default: false, null: false
      t.datetime :published_at
      t.timestamps
    end

    create_table :lineup_slots do |t|
      t.references :lineup, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :line_type, null: false
      t.integer :position, null: false
      t.string :confirmation, default: "pending", null: false
      t.datetime :confirmed_at
      t.timestamps
    end

    add_index :lineups, [:match_id], unique: true
    add_index :lineup_slots, [:lineup_id, :user_id], unique: true
  end
end
