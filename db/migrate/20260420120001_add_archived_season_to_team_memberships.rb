class AddArchivedSeasonToTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :team_memberships, :archived_season, :string
    add_index  :team_memberships, :archived_season

    # Existing unique index on (user_id, tennis_team_id) would prevent a
    # player rejoining a team after their previous season was archived.
    # Replace it with a partial unique index scoped to active memberships
    # only, so (user, team) can have many archived rows + one active.
    remove_index :team_memberships,
                 name: "index_team_memberships_on_user_id_and_tennis_team_id"

    add_index :team_memberships, [ :user_id, :tennis_team_id ],
              unique: true,
              where: "archived_season IS NULL",
              name: "index_team_memberships_unique_active"
  end
end
