class AddTeamInfoFields < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :district, :string             # e.g. "Philadelphia"
    add_column :tennis_teams, :flight, :string               # e.g. "4.0 Women Delches - Tues / Sub-Flight 2"
    add_column :tennis_teams, :home_court_address, :string    # facility street address
    add_column :users, :phone, :string                        # captain / player contact phone
  end
end
