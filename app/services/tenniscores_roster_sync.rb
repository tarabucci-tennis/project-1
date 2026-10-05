# Keeps each league team's Court Report roster in step with its public
# tenniscores page (Bux-Mont, Del-Tri, Inter-Club/Cup) — every team that has a
# `tenniscores_url`, so a new season's team is covered as soon as its link is
# saved. Run nightly.
#
# Captains and players on the site become members (matched to existing users
# by name, otherwise created). "(C)" / "(CC)" on the site make that player
# captain / co-captain. It only ever ADDS people and promotes roles — it never
# removes anyone or demotes a captain set in Court Report, and it skips the
# "Players Subbing for this Team" list (they belong to other teams).
#
# The ratings on these sites are each league's own numbers, not USTA's, so
# they are NOT written to anyone's rating.
class TenniscoresRosterSync
  Result = Struct.new(:added, :notes, keyword_init: true) do
    def to_s
      (added.map { |team, n| "#{team}: +#{n} players" } + notes).join(" · ")
    end
  end

  ROLE_RANK = { "player" => 0, "co_captain" => 1, "captain" => 2 }.freeze

  def call
    added = {}
    notes = []

    TennisTeam.where(archived: false).where.not(tenniscores_url: [ nil, "" ]).find_each do |team|
      roster = TenniscoresRoster.new(team.tenniscores_url).fetch_fresh
      players = roster.reject { |p| p.group.to_s.match?(/sub/i) }
      if players.empty?
        notes << "#{team.name}: no roster found on the league site"
        next
      end

      count = 0
      players.each { |p| count += 1 if sync_player(team, p) }
      added[team.name] = count if count.positive?
    rescue StandardError => e
      notes << "#{team.name}: #{e.class} — #{e.message}"
    end

    Result.new(added: added, notes: notes)
  end

  private

  # True when the player was newly added to the team.
  def sync_player(team, p)
    user = User.where("LOWER(name) = ?", p.name.downcase).first || User.create!(name: p.name)
    role = { "C" => "captain", "CC" => "co_captain" }.fetch(p.role.to_s, "player")

    membership = team.team_memberships.find_by(user: user)
    if membership.nil?
      TeamMembership.create!(user: user, tennis_team: team, role: role)
      return true
    end

    if membership.archived_season.nil? && ROLE_RANK[role] > ROLE_RANK.fetch(membership.role, 0)
      membership.update!(role: role)
    end
    false
  end
end
