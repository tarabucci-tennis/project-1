# Who typed a line's score and when ("Entered by Jaci, Nov 18"), so a player
# entering just her own line is traceable. Nothing existing changes.
class AddEnteredByToMatchLines < ActiveRecord::Migration[8.1]
  def change
    add_column :match_lines, :entered_by_id, :integer
    add_column :match_lines, :entered_at, :datetime
  end
end
