# When two person records are merged (Admin > Possible duplicates), remember
# "old id -> kept id" so old profile links (/players/26) forward to the kept
# record instead of "Player not found".
class CreateMergedUsers < ActiveRecord::Migration[8.1]
  # Merges already done on Nov 16 2026, ids from Tara's re-check:
  # Joanne Steinberg 26 -> 35, Sarah Dougherty 40 -> 155.
  KNOWN = { 26 => 35, 40 => 155 }.freeze

  def up
    create_table :merged_users do |t|
      t.integer :from_user_id, null: false
      t.integer :into_user_id, null: false
      t.timestamps
    end
    add_index :merged_users, :from_user_id, unique: true

    KNOWN.each do |from, into|
      next if select_value("SELECT 1 FROM users WHERE id = #{from.to_i}")      # old record still exists
      next unless select_value("SELECT 1 FROM users WHERE id = #{into.to_i}")  # kept record must exist
      execute "INSERT INTO merged_users (from_user_id, into_user_id, created_at, updated_at) " \
              "VALUES (#{from.to_i}, #{into.to_i}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    end
  end

  def down
    drop_table :merged_users
  end
end
