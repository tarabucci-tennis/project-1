# A private link per match where players say if they can play, no account needed.
class AddAvailabilityTokenToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :availability_token, :string
    add_index :matches, :availability_token, unique: true
  end
end
