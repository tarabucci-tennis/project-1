class CreateMatchLines < ActiveRecord::Migration[8.1]
  def change
    create_table :match_lines do |t|
      t.references :match, null: false, foreign_key: true
      t.string :line_type, null: false              # "singles" or "doubles"
      t.integer :position, null: false               # 1, 2, 3, 4, 5 (line number)
      t.string :result                               # "win" or "loss"
      t.string :set1_score                           # "6-3"
      t.string :set2_score                           # "4-6"
      t.string :set3_score                           # "7-5" (tiebreaker set, if any)
      t.timestamps
    end

    # Which players played on which line
    create_table :match_line_players do |t|
      t.references :match_line, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :match_lines, [ :match_id, :position ], unique: true
    add_index :match_line_players, [ :match_line_id, :user_id ], unique: true
  end
end
