class AddLineupsToFriendlies < ActiveRecord::Migration[8.1]
  def change
    add_column :friendlies, :sets_count, :integer, default: 3, null: false
    add_column :friendlies, :lineup, :text
    add_column :friendly_spots, :in_lineup, :boolean, default: true, null: false
  end
end
