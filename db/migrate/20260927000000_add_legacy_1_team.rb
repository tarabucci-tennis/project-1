# Adds Tara's Del-Tri Division 1 team "Legacy 1" (2026-27 season) with its
# full 18-match schedule, taken from the team's Tenniscores calendar export
# (Legacy_1.ics). Tara plays on it; the captain isn't known yet, so nobody is
# made captain here.
#
# Home/away comes from the match site: at Legacy Tennis => home, anywhere
# else => away. (The .ics titles are "Away vs Home", but the site is the
# reliable signal.) Times are the league's local start times.
#
# Roster is NOT included — the .ics carries no player names.
#
# Idempotent: finds-or-creates the team, Tara's membership, and each match
# (by date + opponent), re-applying time/site/home-away every run. A match
# with a result already entered is left alone.
class AddLegacy1Team < ActiveRecord::Migration[8.1]
  HOME_COURT = "Legacy Tennis, 4842 Ridge Ave, Philadelphia PA 19129".freeze

  # [y, m, d], hour, minute, opponent, site (nil => home at Legacy Tennis)
  MATCHES = [
    [ [ 2026, 10, 2 ],  10, 0,  "Gulph Mills 1",     nil ],
    [ [ 2026, 10, 9 ],  10, 0,  "Tennis Addiction 1", nil ],
    [ [ 2026, 10, 16 ], 12, 0,  "DVTA 1",            "DVTA" ],
    [ [ 2026, 10, 23 ], 13, 30, "Penn Oaks 2",       "Brandywine Racquet Club" ],
    [ [ 2026, 10, 30 ], 10, 0,  "HPTA 2",            nil ],
    [ [ 2026, 11, 6 ],  12, 30, "Radnor Racquet 1",  "Radnor Racquet Club" ],
    [ [ 2026, 11, 13 ], 10, 0,  "HPTA 1",            nil ],
    [ [ 2026, 11, 20 ], 9,  0,  "Penn Oaks 1",       "Penn Oaks Tennis & Fitness Club" ],
    [ [ 2026, 12, 4 ],  10, 0,  "Brandywine 1",      nil ],
    [ [ 2027, 1, 8 ],   9,  30, "Gulph Mills 1",     "Gulph Mills Tennis Club" ],
    [ [ 2027, 1, 15 ],  12, 30, "Tennis Addiction 1", "Tennis Addiction Sports Club" ],
    [ [ 2027, 1, 22 ],  10, 0,  "DVTA 1",            nil ],
    [ [ 2027, 1, 29 ],  10, 0,  "Penn Oaks 2",       nil ],
    [ [ 2027, 2, 5 ],   12, 0,  "HPTA 2",            "HPTA" ],
    [ [ 2027, 2, 19 ],  10, 0,  "Radnor Racquet 1",  nil ],
    [ [ 2027, 2, 26 ],  12, 0,  "HPTA 1",            "HPTA" ],
    [ [ 2027, 3, 5 ],   10, 0,  "Penn Oaks 1",       nil ],
    [ [ 2027, 3, 12 ],  10, 30, "Brandywine 1",      "Brandywine Racquet Club" ]
  ].freeze

  def up
    tara = User.find_by(email: "tarabucci@gmail.com") || User.find_by("LOWER(name) = ?", "tara bucci")
    return unless tara

    team = TennisTeam.where("LOWER(name) = ?", "legacy 1").first || TennisTeam.new(name: "Legacy 1")
    team.assign_attributes(
      user:            team.user || tara,
      league_category: "Local",
      league_name:     (team.league_name.presence || "Del-Tri"),
      standings_style: (team.standings_style.presence || "points"),
      team_type:       (team.team_type.presence || "Division 1"),
      section:         (team.section.presence || "Del-Tri"),
      gender:          (team.gender.presence || "Women's"),
      home_court:      (team.home_court.presence || HOME_COURT),
      season_name:     (team.season_name.presence || "2026-27"),
      start_date:      (team.start_date || Date.new(2026, 10, 2))
    )
    team.save!

    TeamMembership.find_or_create_by!(user: tara, tennis_team: team, archived_season: nil) do |m|
      m.role = "player"
    end

    MATCHES.each do |(y, mo, d), hour, min, opp, site|
      date  = Time.zone.local(y, mo, d, hour, min)
      home  = site.nil?
      match = team.matches.where(match_date: date.all_day)
                  .where("LOWER(opponent) = ?", opp.downcase).first
      next if match&.result.present?

      match ||= team.matches.new(opponent: opp)
      match.assign_attributes(
        match_date: date,
        home_away:  home ? "home" : "away",
        match_time: date.strftime("%-l:%M %p"),
        location:   home ? "Legacy Tennis" : site
      )
      match.save!
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
