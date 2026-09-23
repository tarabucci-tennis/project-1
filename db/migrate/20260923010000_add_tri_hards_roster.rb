# Fills in the Tri Hards roster (from the team's TennisLink page). Rachel
# Chadwin captains and Becky Auslander is co-captain; everyone else is a
# player. Tara is already on the team from the previous migration, so she's
# not re-added here. Existing users (many already play on Tara's other teams)
# are reused by name; the rest are created as placeholders.
#
# Idempotent: finds-or-creates each user and their active membership, and
# re-applies the intended role each run. No-ops if the team doesn't exist
# yet (e.g. an empty CI database).
class AddTriHardsRoster < ActiveRecord::Migration[8.1]
  # name => role. Anyone not listed here is a "player".
  LEADERS = {
    "rachel chadwin" => "captain",
    "becky auslander" => "co_captain"
  }.freeze

  ROSTER = [
    "Jaclyn Groenen", "Rebecca Feinberg", "Elizabeth Balcer", "Becky Auslander",
    "Jouna Villani", "Rachel Chadwin", "Laura Newth", "Doris Kerr",
    "Sharon Garlepp", "Kim Cercone", "Christina Faidley", "Jody Staples",
    "Amanda Neczypor", "Alexis Fishkind", "Gwynne Barnes", "Dana Goldblum"
  ].freeze

  def up
    team = TennisTeam.where("LOWER(name) IN (?)", [ "tri hards", "tri-hards" ]).first
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
