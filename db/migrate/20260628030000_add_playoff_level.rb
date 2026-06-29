class AddPlayoffLevel < ActiveRecord::Migration[8.1]
  def change
    # The playoff level a team has advanced to (e.g. "Districts"), nil = regular
    # season. On a match, which stage it belongs to (nil = regular season).
    add_column :tennis_teams, :playoff_level, :string
    add_column :matches, :playoff_level, :string
  end
end
