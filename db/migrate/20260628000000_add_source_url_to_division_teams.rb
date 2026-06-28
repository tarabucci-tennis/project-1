class AddSourceUrlToDivisionTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :division_teams, :source_url, :string
  end
end
