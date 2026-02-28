class CreateTennisTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :tennis_teams do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :team_type
      t.string :section
      t.string :gender
      t.decimal :rating
      t.date :start_date

      t.timestamps
    end
  end
end
