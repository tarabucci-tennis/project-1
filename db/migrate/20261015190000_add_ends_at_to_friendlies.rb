class AddEndsAtToFriendlies < ActiveRecord::Migration[8.1]
  def change
    add_column :friendlies, :ends_at, :datetime
  end
end
