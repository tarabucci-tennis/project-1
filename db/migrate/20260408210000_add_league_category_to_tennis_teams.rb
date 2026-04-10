class AddLeagueCategoryToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :league_category, :string, default: "USTA", null: false
    add_column :tennis_teams, :home_court, :string
    add_column :tennis_teams, :season_name, :string
    add_index :tennis_teams, :league_category
  end
end
