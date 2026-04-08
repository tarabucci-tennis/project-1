class AddNotificationPreferenceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_preference, :string
  end
end
