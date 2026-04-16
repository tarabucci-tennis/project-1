class AllowNullUserOnLineupSlots < ActiveRecord::Migration[8.1]
  def change
    # Let lineup slots exist without a user assigned. This lets the edit
    # form render 9 empty slot cards (1S + 4×2D×2) that the captain fills
    # in by picking players from the dropdowns. Before this, we had to
    # create each slot with a non-null placeholder user, and the unique
    # (lineup_id, user_id) index meant the second doubles slot for the
    # same placeholder crashed with RecordNotUnique.
    change_column_null :lineup_slots, :user_id, true
  end
end
