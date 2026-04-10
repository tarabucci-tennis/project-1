class CreateLineups < ActiveRecord::Migration[8.1]
  def change
    unless table_exists?(:lineups)
      create_table :lineups do |t|
        t.references :match, null: false, foreign_key: true
        t.boolean :published, default: false, null: false
        t.datetime :published_at
        t.timestamps
      end
    end

    unless table_exists?(:lineup_slots)
      create_table :lineup_slots do |t|
        t.references :lineup, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.string :line_type, null: false
        t.integer :position, null: false
        t.string :confirmation, default: "pending", null: false
        t.datetime :confirmed_at
        t.timestamps
      end
    end

    add_index :lineups, [:match_id], unique: true unless index_exists?(:lineups, :match_id)
    add_index :lineup_slots, [:lineup_id, :user_id], unique: true unless index_exists?(:lineup_slots, [:lineup_id, :user_id])
  end
end
