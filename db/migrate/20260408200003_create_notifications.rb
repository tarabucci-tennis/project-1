class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tennis_team, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :body, null: false
      t.boolean :read, default: false, null: false
      t.timestamps
    end

    add_index :notifications, [ :user_id, :read ]
  end
end
