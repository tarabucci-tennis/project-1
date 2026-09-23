# Adds Tara's USTA Adult Tri-Level team "Tri Hards" (USTA/Middle States,
# Philadelphia — Tri Level Womens 4.0-3.0 Wednesday/Sub-Flight 2) with its
# full 8-match schedule, captained by Rachel Chadwin (Tara plays on it, she
# is not the captain).
#
# Schedule times per Tara: every HOME match is 10:00 AM at Radnor Valley
# Country Club; AWAY matches carry no time (TennisLink's "4:00 AM" is junk).
#
# Idempotent: finds-or-creates the team, its two known members, and each
# match (by date + opponent), and re-applies the correct home/away, time and
# site every run — so it also fixes a match if it was hand-entered wrong.
class AddTriHardsTeam < ActiveRecord::Migration[8.1]
  HOME_COURT = "Radnor Valley Country Club".freeze

  # date, opponent, home? (home => 10:00 AM at Radnor Valley; away => no time)
  MATCHES = [
    { d: [ 2026, 9, 9 ],   opp: "Idle Shots",              home: true },
    { d: [ 2026, 9, 23 ],  opp: "Legacy Tri-fectas",       home: true },
    { d: [ 2026, 9, 30 ],  opp: "Tri-Aces",                home: false, site: "Legacy Youth Tennis and Education" },
    { d: [ 2026, 10, 7 ],  opp: "DVTA Triple Threat",      home: false, site: "Bryn Mawr Racquet Club" },
    { d: [ 2026, 10, 14 ], opp: "Philadelphia Cricket Red", home: false, site: "Philadelphia Cricket Club" },
    { d: [ 2026, 10, 21 ], opp: "Cynwyd Court Couture",    home: true },
    { d: [ 2026, 10, 28 ], opp: "Llanerch",                home: true },
    { d: [ 2026, 11, 4 ],  opp: "DVTA Love All Ladies",    home: false, site: "Bryn Mawr Racquet Club" }
  ].freeze

  def up
    tara = User.find_by(email: "tarabucci@gmail.com") || User.find_by("LOWER(name) = ?", "tara bucci")
    return unless tara

    team = TennisTeam.where("LOWER(name) IN (?)", [ "tri hards", "tri-hards" ]).first ||
           TennisTeam.new(name: "Tri Hards")
    team.assign_attributes(
      user:            team.user || tara,
      league_category: "USTA",
      league_name:     (team.league_name.presence || "USTA Adult Tri-Level"),
      standings_style: "usta",
      team_type:       (team.team_type.presence || "Tri-Level"),
      section:         (team.section.presence || "USTA/Middle States"),
      district:        (team.district.presence || "Philadelphia"),
      flight:          (team.flight.presence || "Tri Level Womens 4.0-3.0 Wednesday/Sub-Flight 2"),
      gender:          (team.gender.presence || "Women's"),
      rating:          (team.rating || 4.0),
      home_court:      (team.home_court.presence || HOME_COURT),
      season_name:     (team.season_name.presence || "Fall 2026"),
      start_date:      (team.start_date || Date.new(2026, 9, 9))
    )
    team.save!

    # Rachel Chadwin captains; Tara is a player on this team.
    rachel = User.where("LOWER(name) = ?", "rachel chadwin").first || User.create!(name: "Rachel Chadwin")
    TeamMembership.find_or_create_by!(user: rachel, tennis_team: team, archived_season: nil).update!(role: "captain")
    TeamMembership.find_or_create_by!(user: tara, tennis_team: team, archived_season: nil).update!(role: "player")

    MATCHES.each do |m|
      y, mo, d = m[:d]
      date = Time.zone.local(y, mo, d, m[:home] ? 10 : 12, 0)
      match = team.matches.where(match_date: date.all_day)
                  .where("LOWER(opponent) = ?", m[:opp].downcase).first
      match ||= team.matches.new(match_date: date, opponent: m[:opp])
      match.assign_attributes(
        home_away:  m[:home] ? "home" : "away",
        match_time: (m[:home] ? "10:00 AM" : nil),
        location:   (m[:home] ? HOME_COURT : m[:site])
      )
      match.save!
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
