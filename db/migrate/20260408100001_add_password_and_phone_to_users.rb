class AddPasswordAndPhoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :phone, :string
    add_column :users, :invite_token, :string
    add_column :users, :invited_at, :datetime
    add_column :users, :super_admin, :boolean, default: false, null: false
    add_index :users, :invite_token, unique: true
  end
end
