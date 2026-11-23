# Archive a friendly: hide it from every list without deleting it (Tara, Nov 23 2026).
class AddArchivedAtToFriendlies < ActiveRecord::Migration[8.1]
  def change
    add_column :friendlies, :archived_at, :datetime
    add_index :friendlies, :archived_at
  end
end
