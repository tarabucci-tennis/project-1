# AGC Aces wear navy & white, not "Blue & white" (Tara, Oct 16 2026).
# Only replaces the value our earlier update put there, never a captain's edit.
class AgcAcesColorsNavyAndWhite < ActiveRecord::Migration[8.1]
  class Team < ActiveRecord::Base
    self.table_name = "tennis_teams"
  end

  def up
    Team.where("LOWER(name) = ?", "agc aces")
        .where(team_colors: [ nil, "", "Blue & white" ])
        .update_all(team_colors: "Navy & white")
  end

  def down
    # Data only.
  end
end
