class CreateFriendlyScores < ActiveRecord::Migration[8.1]
  def change
    create_table :friendly_scores do |t|
      t.references :friendly, null: false, foreign_key: true
      t.integer :court, null: false
      t.string :pair_a
      t.string :pair_b
      t.text :sets
      t.string :entered_by, null: false
      t.text :history
      t.timestamps
    end
    add_index :friendly_scores, [ :friendly_id, :court ], unique: true
    add_column :friendlies, :scores_locked_at, :datetime
  end
end
