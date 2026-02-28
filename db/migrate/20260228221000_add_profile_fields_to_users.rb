class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :location, :string
    add_column :users, :ntrp_rating, :decimal
    add_column :users, :ntrp_rating_date, :date
    add_column :users, :dynamic_rating, :decimal
    add_column :users, :dynamic_rating_date, :date
  end
end
