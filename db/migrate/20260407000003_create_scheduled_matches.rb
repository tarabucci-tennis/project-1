class CreateScheduledMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_matches do |t|
      t.references :team, null: false, foreign_key: true
      t.date :match_date, null: false
      t.string :match_time
      t.string :opponent_team, null: false
      t.string :home_away, default: "home"
      t.string :location
      t.timestamps
    end

    add_index :scheduled_matches, [ :team_id, :match_date ]
  end
end
