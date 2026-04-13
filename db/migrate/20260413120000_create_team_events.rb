class CreateTeamEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :team_events do |t|
      t.references :tennis_team, null: false, foreign_key: true
      t.string :title, null: false
      t.date :event_date, null: false
      t.string :start_time          # free-form like "6:00 PM" to match Match#match_time
      t.string :location
      t.string :kind, null: false   # "practice" | "clinic" | "friendly"
      t.text :notes
      t.timestamps
    end

    add_index :team_events, [ :tennis_team_id, :event_date ]
  end
end
