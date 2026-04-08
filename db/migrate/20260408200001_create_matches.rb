class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :tennis_team, null: false, foreign_key: true
      t.datetime :match_date, null: false
      t.string :location
      t.string :opponent
      t.text :notes
      t.timestamps
    end

    add_index :matches, [ :tennis_team_id, :match_date ]
  end
end
