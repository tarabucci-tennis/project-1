class CreateTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :team_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tennis_team, null: false, foreign_key: true
      t.string :role, default: "player", null: false
      t.string :notification_preference, default: "every_update", null: false
      t.timestamps
    end

    add_index :team_memberships, [ :user_id, :tennis_team_id ], unique: true
  end
end
