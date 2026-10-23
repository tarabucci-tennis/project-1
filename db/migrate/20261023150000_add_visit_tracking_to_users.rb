# Admin-only member activity: how often each person signs in and on how many
# different days they've used the site. Counting starts from this update.
class AddVisitTrackingToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :days_visited, :integer, default: 0, null: false
    add_column :users, :last_seen_at, :datetime
    add_column :users, :last_seen_on, :date
  end
end
