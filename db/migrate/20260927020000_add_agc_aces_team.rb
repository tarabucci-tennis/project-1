# Adds Tara's second USTA Adult Tri-Level team "AGC Aces" (USTA/Middle
# States, Philadelphia — Tri Level Womens 4.5-3.5 Wednesday) with its full
# 8-match schedule, from the team's TennisLink "Match Schedule by Team"
# export. Gwynne Barnes captains, Stephanie Finnerty is co-captain, Tara
# plays on it. The rest of the roster isn't in the export.
#
# Times: TennisLink lists every match at "4:00 AM", which is junk (same as
# Tri Hards), so no match time is set; captains can add it via Edit Match.
#
# Idempotent: finds-or-creates the team, its three known members, and each
# match (by date + opponent), re-applying home/away and site every run. A
# match with a result already entered is left alone.
class AddAgcAcesTeam < ActiveRecord::Migration[8.1]
  HOME_COURT = "Aronimink Golf Club".freeze

  # date, opponent, site (nil => home at Aronimink)
  MATCHES = [
    [ [ 2026, 9, 9 ],   "Whitchester Tri",      nil ],
    [ [ 2026, 9, 16 ],  "Alley Cats",           nil ],
    [ [ 2026, 9, 23 ],  "The Cynwyd Ringers",   "Cynwyd Club" ],
    [ [ 2026, 9, 30 ],  "Hot Shots",            "JKST Gulph Mills Tennis" ],
    [ [ 2026, 10, 7 ],  "Pennsbury Tricksters", "Pennsbury Racquet and Athletic Center" ],
    [ [ 2026, 10, 14 ], "Unmatchables",         "Conestoga Swim Club" ],
    [ [ 2026, 10, 21 ], "Legacy",               nil ],
    [ [ 2026, 10, 28 ], "The Cynwyd Ringers",   nil ]
  ].freeze

  def up
    tara = User.find_by(email: "tarabucci@gmail.com") || User.find_by("LOWER(name) = ?", "tara bucci")
    return unless tara

    team = TennisTeam.where("LOWER(name) = ?", "agc aces").first || TennisTeam.new(name: "AGC Aces")
    team.assign_attributes(
      user:               team.user || tara,
      league_category:    "USTA",
      league_name:        (team.league_name.presence || "USTA Adult Tri-Level"),
      standings_style:    (team.standings_style.presence || "usta"),
      team_type:          (team.team_type.presence || "Tri-Level"),
      section:            (team.section.presence || "USTA/Middle States"),
      district:           (team.district.presence || "Philadelphia"),
      flight:             (team.flight.presence || "Tri Level Womens 4.5-3.5 Wednesday"),
      gender:             (team.gender.presence || "Women's"),
      rating:             (team.rating || 4.5),
      home_court:         (team.home_court.presence || HOME_COURT),
      home_court_address: (team.home_court_address.presence || "3600 Saint Davids Rd, Newtown Square, PA 19073"),
      season_name:        (team.season_name.presence || "Fall 2026"),
      start_date:         (team.start_date || Date.new(2026, 9, 9))
    )
    team.save!

    { "Gwynne Barnes" => "captain", "Stephanie Finnerty" => "co_captain" }.each do |name, role|
      user = User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
      TeamMembership.find_or_create_by!(user: user, tennis_team: team, archived_season: nil).update!(role: role)
    end
    TeamMembership.find_or_create_by!(user: tara, tennis_team: team, archived_season: nil) { |m| m.role = "player" }

    MATCHES.each do |(y, mo, d), opp, site|
      date  = Time.zone.local(y, mo, d, 12, 0)
      home  = site.nil?
      match = team.matches.where(match_date: date.all_day)
                  .where("LOWER(opponent) = ?", opp.downcase).first
      next if match&.result.present?

      match ||= team.matches.new(match_date: date, opponent: opp)
      match.assign_attributes(
        home_away: home ? "home" : "away",
        location:  home ? HOME_COURT : site
      )
      match.save!
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
