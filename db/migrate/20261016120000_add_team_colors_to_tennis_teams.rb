# What the team wears, set by the captain (e.g. "Any pink & black"). Shown
# next to the team name and in the shared match text so subs know what to
# wear. Fills in the two colors Tara gave (Oct 16 2026) if still blank.
class AddTeamColorsToTennisTeams < ActiveRecord::Migration[8.1]
  class Team < ActiveRecord::Base
    self.table_name = "tennis_teams"
  end

  KNOWN = { "legacy 1" => "Any pink & black", "advantage us" => "All black" }.freeze

  def up
    add_column :tennis_teams, :team_colors, :string
    Team.reset_column_information
    KNOWN.each do |name, colors|
      Team.where("LOWER(name) = ?", name).where(team_colors: [ nil, "" ]).update_all(team_colors: colors)
    end
  end

  def down
    remove_column :tennis_teams, :team_colors
  end
end
