class AddAnonymousToFeedbacks < ActiveRecord::Migration[8.1]
  # "Send anonymously" on the Beta feedback popup (Tara, Nov 24 2026): no
  # account or name is kept with the message. Adds only.
  def change
    add_column :feedbacks, :anonymous, :boolean, null: false, default: false
  end
end
