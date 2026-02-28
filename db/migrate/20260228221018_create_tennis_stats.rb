class CreateTennisStats < ActiveRecord::Migration[8.1]
  def change
    create_table :tennis_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year
      t.integer :matches_total
      t.integer :matches_won
      t.integer :matches_lost
      t.integer :sets_total
      t.integer :sets_won
      t.integer :sets_lost
      t.integer :games_total
      t.integer :games_won
      t.integer :games_lost
      t.integer :defaults

      t.timestamps
    end
  end
end
