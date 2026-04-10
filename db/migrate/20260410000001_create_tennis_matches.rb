class CreateTennisMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :tennis_matches do |t|
      t.references :tennis_team, null: false, foreign_key: true
      t.date :match_date
      t.string :match_type
      t.string :opponent_team
      t.string :location
      t.string :result
      t.string :score
      t.string :partner
      t.string :opponent_players
      t.integer :court_number

      t.timestamps
    end
  end
end
