class AddCalendarImport < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ical_url, :string

    create_table :external_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :location
      t.boolean :all_day, default: false, null: false
      t.string :uid
      t.timestamps
    end
    add_index :external_events, [ :user_id, :starts_at ]
  end
end
