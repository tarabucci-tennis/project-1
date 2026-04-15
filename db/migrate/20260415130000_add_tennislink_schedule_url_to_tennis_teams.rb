class AddTennislinkScheduleUrlToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :tennislink_schedule_url, :string
  end
end
