class CreateFeedbacks < ActiveRecord::Migration[8.1]
  # Beta feedback (Tara, Nov 24 2026): messages from the Beta tag popup and the
  # one-time welcome card, read by admins on /admin/feedback. Adds only.
  def change
    create_table :feedbacks do |t|
      t.references :user, foreign_key: true
      t.string :name
      t.text :message, null: false
      t.string :page
      t.timestamps
    end
    add_column :users, :beta_welcomed_at, :datetime
  end
end
