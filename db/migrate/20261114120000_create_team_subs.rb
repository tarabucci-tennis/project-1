# Each team's list of subs: players who aren't on the roster but fill in.
class CreateTeamSubs < ActiveRecord::Migration[8.1]
  def change
    create_table :team_subs do |t|
      t.references :tennis_team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :note
      t.integer :added_by_id
      t.timestamps
    end
    add_index :team_subs, [ :tennis_team_id, :user_id ], unique: true
  end
end
