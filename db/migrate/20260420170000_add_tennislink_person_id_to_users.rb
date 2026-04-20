class AddTennislinkPersonIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tennislink_person_id, :string
  end
end
