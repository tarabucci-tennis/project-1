# Fills in the Legacy 1 roster (Del-Tri Division 1, 2026-27) from the team's
# Tenniscores page. Annie Duke captains; everyone else is a player. Tara is
# already on the team from the previous migration and is left as-is.
#
# The Del-Tri ratings shown on that page (4.0 / 4.5) are Del-Tri's own
# numbers, not USTA ratings, so they are deliberately NOT written to anyone's
# rating. (Only USTA sets a player's real rating.)
#
# "Beth Overley-Adamson" was cut off on the source page ("Overley-Adamsc");
# the spelling is a best guess and can be corrected on /users.
#
# Idempotent: finds-or-creates each user (by name) and their active
# membership, re-applying the role each run. No-ops if the team doesn't
# exist yet (e.g. an empty CI database).
class AddLegacy1Roster < ActiveRecord::Migration[8.1]
  CAPTAIN = "annie duke".freeze

  ROSTER = [
    "Annie Duke", "Marla Friedman", "Beth Overley-Adamson", "Erin Paone",
    "Lauren Urban", "Mary Assini", "Amy Lutz", "Kali Curran",
    "Marcea Hummel", "Jackie Zivitz", "Heather Badami"
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "legacy 1").first
    return unless team

    ROSTER.each do |name|
      user = User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
      membership = TeamMembership.find_or_create_by!(user: user, tennis_team: team, archived_season: nil)
      membership.update!(role: name.downcase == CAPTAIN ? "captain" : "player")
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
