class AddConfirmationToLineupSlots < ActiveRecord::Migration[8.1]
  def change
    add_column :lineup_slots, :confirmed, :boolean, default: false
    add_column :lineup_slots, :confirmation_message, :string
    add_column :lineup_slots, :confirmed_at, :datetime
  end
end
