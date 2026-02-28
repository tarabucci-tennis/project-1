class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.boolean :admin, default: false, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
