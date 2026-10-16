# AGC Aces wear blue & white (Tara, Oct 16 2026). Only fills it in if blank,
# so a captain's later edit is never overwritten.
class SetAgcAcesTeamColors < ActiveRecord::Migration[8.1]
  class Team < ActiveRecord::Base
    self.table_name = "tennis_teams"
  end

  def up
    Team.where("LOWER(name) = ?", "agc aces").where(team_colors: [ nil, "" ]).update_all(team_colors: "Blue & white")
  end

  def down
    # Data only.
  end
end
