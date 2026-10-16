# Each team's own "Open Full Stats Sheet" link. It used to be one fixed link
# shown on every team, so teams opened another team's sheet. Blank = no button.
class AddStatsSheetUrlToTennisTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tennis_teams, :stats_sheet_url, :string
  end
end
