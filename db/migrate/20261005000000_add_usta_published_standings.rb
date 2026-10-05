# Stores USTA's own published numbers from a TennisLink "Team Summary" upload,
# shown as-is and never recalculated (USTA points are weighted per position;
# its games-won % excludes defaulted matches):
#   * tennis_teams — our team's published standings row + when it was synced
#   * division_teams — each rival's published games-won %
#   * matches — USTA's confirmation status ("Confirmed by 48 hr rule", ...)
class AddUstaPublishedStandings < ActiveRecord::Migration[8.1]
  def change
    change_table :tennis_teams, bulk: true do |t|
      t.integer  :usta_matches_played
      t.integer  :usta_points
      t.integer  :usta_sets_won
      t.integer  :usta_sets_lost
      t.integer  :usta_games_won
      t.integer  :usta_games_lost
      t.decimal  :usta_games_won_pct, precision: 5, scale: 2
      t.datetime :usta_synced_at
    end
    add_column :division_teams, :games_won_pct, :decimal, precision: 5, scale: 2
    add_column :matches, :usta_status, :string
  end
end
