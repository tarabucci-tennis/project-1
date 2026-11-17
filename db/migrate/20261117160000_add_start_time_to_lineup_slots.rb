# Split court times (Tara, Nov 17 2026): each line can start at its own time
# ("10:30 AM"); blank = the match's time. Never copied from last week.
class AddStartTimeToLineupSlots < ActiveRecord::Migration[8.1]
  def change
    add_column :lineup_slots, :start_time, :string
  end
end
