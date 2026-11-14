class AddTennisFlagToExternalEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :external_events, :tennis, :boolean, default: false, null: false
  end
end
