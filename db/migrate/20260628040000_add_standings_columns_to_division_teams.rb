class AddStandingsColumnsToDivisionTeams < ActiveRecord::Migration[8.1]
  def change
    # Full USTA-style standings numbers a captain can enter by hand for
    # opponents (TennisLink doesn't publish these publicly). Points-based
    # leagues (Del-Tri / Inter-Club) ignore these and keep using `wins`.
    add_column :division_teams, :matches_played, :integer, default: 0, null: false
    add_column :division_teams, :points, :integer, default: 0, null: false
    add_column :division_teams, :sets_won, :integer, default: 0, null: false
    add_column :division_teams, :sets_lost, :integer, default: 0, null: false
    add_column :division_teams, :games_won, :integer, default: 0, null: false
    add_column :division_teams, :games_lost, :integer, default: 0, null: false
  end
end
