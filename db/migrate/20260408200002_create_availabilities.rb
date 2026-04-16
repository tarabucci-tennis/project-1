class CreateAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :availabilities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.string :status, default: "no_response", null: false
      t.string :message
      t.timestamps
    end

    add_index :availabilities, [ :user_id, :match_id ], unique: true
  end
end
