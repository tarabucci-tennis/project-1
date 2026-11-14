# A sub on a team's Subs list: someone who isn't on the roster but fills in
# when a rostered player can't play. Captains keep the list; Set Lineup
# offers these names for every line.
class TeamSub < ApplicationRecord
  belongs_to :tennis_team
  belongs_to :user
  belongs_to :added_by, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :tennis_team_id }
  validates :note, length: { maximum: 80 }
end
