class CreatePlayerMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deltri_player_url, :string

    create_table :player_matches do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :league          # e.g. "Del-Tri"
      t.string  :division         # e.g. "Division 1"
      t.date    :played_on
      t.string  :date_label       # e.g. "10/03"
      t.string  :match_label      # e.g. "Legacy 1 vs Gulph Mills 1"
      t.string  :line_label        # e.g. "Line 5"
      t.string  :partner
      t.string  :opponents
      t.string  :score
      t.string  :result           # "win" / "loss"
      t.string  :source           # "deltri"
      t.string  :source_key        # stable id from the source, for idempotency
      t.timestamps
    end

    add_index :player_matches, [ :user_id, :source, :source_key ], unique: true,
              name: "index_player_matches_on_user_and_source_key"
  end
end
