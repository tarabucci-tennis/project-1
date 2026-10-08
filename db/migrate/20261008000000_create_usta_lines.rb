# One row per USTA line played (e.g. "#1 Doubles" in team match 1012187865),
# saved from TennisLink "Individual Result" exports that players upload. The
# same line shows up in the files of everyone who played it, so rows are
# unique per (TennisLink match ID, line) and later uploads just skip them.
# Names are stored as TennisLink prints them; nothing links to users here.
class CreateUstaLines < ActiveRecord::Migration[8.1]
  def change
    create_table :usta_lines do |t|
      t.string  :usta_match_id, null: false
      t.string  :match_type, null: false
      t.date    :match_date
      t.string  :league
      t.string  :section
      t.string  :district
      t.string  :level
      t.string  :line_type
      t.integer :position
      t.string  :winner_1
      t.string  :winner_2
      t.string  :loser_1
      t.string  :loser_2
      t.string  :score
      t.references :uploaded_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :usta_lines, [ :usta_match_id, :match_type ], unique: true
    add_index :usta_lines, :match_date
  end
end
