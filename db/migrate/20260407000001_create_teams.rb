class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :team_type
      t.string :section
      t.string :gender
      t.decimal :rating
      t.references :captain, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
