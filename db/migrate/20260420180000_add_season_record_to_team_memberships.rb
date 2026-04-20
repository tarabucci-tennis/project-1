class AddSeasonRecordToTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :team_memberships, :season_wins,     :integer
    add_column :team_memberships, :season_losses,   :integer
    add_column :team_memberships, :season_position, :string
  end
end
