class CreateCaptainNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :captain_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :scheduled_match, null: false, foreign_key: true
      t.references :team_player, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :message
      t.boolean :read, default: false, null: false
      t.timestamps
    end

    add_index :captain_notifications, [ :user_id, :read ]
  end
end
