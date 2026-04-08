class AddResultFieldsToScheduledMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :scheduled_matches, :team_result, :string
    add_column :scheduled_matches, :courts_won, :integer, default: 0
    add_column :scheduled_matches, :courts_lost, :integer, default: 0
  end
end
