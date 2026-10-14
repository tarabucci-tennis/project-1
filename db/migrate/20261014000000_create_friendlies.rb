# Friendlies: casual matches a player organizes and shares by link. Anyone
# with the link can claim a spot (no account needed); first come, first
# served, 4 players per court, anyone past that goes on the waitlist.
class CreateFriendlies < ActiveRecord::Migration[8.1]
  def change
    create_table :friendlies do |t|
      t.references :organizer, null: false, foreign_key: { to_table: :users }
      t.string   :title, null: false, default: "Friendly"
      t.datetime :starts_at, null: false
      t.string   :location
      t.integer  :courts, null: false, default: 1
      t.text     :notes
      t.string   :token, null: false
      t.timestamps
    end
    add_index :friendlies, :token, unique: true
    add_index :friendlies, :starts_at

    create_table :friendly_spots do |t|
      t.references :friendly, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :guest_key
      t.timestamps
    end
  end
end
