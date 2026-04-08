class CreateMatchScores < ActiveRecord::Migration[8.1]
  def change
    create_table :match_scores do |t|
      t.references :scheduled_match, null: false, foreign_key: true
      t.string :position, null: false
      t.references :player1, foreign_key: { to_table: :team_players }
      t.references :player2, foreign_key: { to_table: :team_players }
      t.string :opponent1_name
      t.string :opponent2_name
      t.string :set1_score
      t.string :set2_score
      t.string :set3_score
      t.string :result
      t.timestamps
    end

    add_index :match_scores, [ :scheduled_match_id, :position ], unique: true
  end
end
