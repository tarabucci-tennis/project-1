class AddMatchTimeToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :match_time, :string  # e.g. "10:30 AM" — separate from date since times are often TBD
  end
end
