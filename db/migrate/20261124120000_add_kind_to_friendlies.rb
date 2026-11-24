class AddKindToFriendlies < ActiveRecord::Migration[8.1]
  # "round_robin" (everyone plays, extras take turns sitting out) or
  # "friendly" (full courts only; extras wait). Existing friendlies keep
  # their old behaviour as "friendly".
  def change
    add_column :friendlies, :kind, :string, null: false, default: "friendly"
  end
end
