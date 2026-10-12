# A team's match format as the league publishes it, e.g. "1S, 3D" (USTA
# winter) — when set, Set Lineup and Enter Results use it instead of the
# league default (USTA 1S+4D, Tri-Level 3D, Del-Tri / Cup 6D).
class AddLineFormatToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :line_format, :string
  end
end
