# Fills in the AGC Aces roster (USTA Tri-Level 4.5-3.5 Wednesday) from the
# team's TennisLink roster page, player numbers 11-32. Gwynne Barnes
# captains and Stephanie Finnerty is co-captain (set by the team migration);
# everyone else is a player. Tara is already on the team.
#
# Existing users (several play on Tara's other teams) are reused by name;
# the rest are created as placeholders.
#
# Idempotent: finds-or-creates each user and their active membership, and
# re-applies the intended role each run. No-ops if the team doesn't exist
# yet (e.g. an empty CI database).
class AddAgcAcesRoster < ActiveRecord::Migration[8.1]
  LEADERS = {
    "gwynne barnes" => "captain",
    "stephanie finnerty" => "co_captain"
  }.freeze

  ROSTER = [
    "Vanessa Halloran", "Gwynne Barnes", "Julia Bartosh", "Diane Walsh",
    "Mary Marshall", "Margaret Auslander", "Amanda Neczypor", "Stephanie Finnerty",
    "Elizabeth Finley", "Kathleen Chambers", "Stephanie Giordano", "Jennifer Walheim",
    "Nese Foster", "Jill Hynes", "Jeanne Craft", "Maria Davidson",
    "Gayle Connelly", "Brooke McDermott", "Diane Doane", "Jody Staples", "Lee Leary"
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "agc aces").first
    return unless team

    ROSTER.each do |name|
      user = User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
      membership = TeamMembership.find_or_create_by!(user: user, tennis_team: team, archived_season: nil)
      membership.update!(role: LEADERS[name.downcase] || "player")
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
