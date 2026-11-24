class AddFormatToFriendlies < ActiveRecord::Migration[8.1]
  # Friendlies can be singles (2 per court) or doubles (4). Round robins are
  # always doubles (Tara, Nov 24 2026). Adds only; existing rows = doubles.
  def change
    add_column :friendlies, :format, :string, null: false, default: "doubles"
  end
end
