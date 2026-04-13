# Court Report seed data
# Real data for Tara's four teams (captured Session 7 from TennisLink,
# Inter-Club website, and Del-Tri website).

# --------------------------------------------------------------
# Helper: create or update a player user (no email = can't log in)
# --------------------------------------------------------------
def find_or_make_player(name, ntrp: nil)
  user = User.find_or_create_by!(name: name) do |u|
    u.admin = false
  end
  user.update!(ntrp_rating: ntrp) if ntrp && user.ntrp_rating.nil?
  user
end

# --------------------------------------------------------------
# Tara (primary user / admin)
# --------------------------------------------------------------
tara = User.find_or_create_by!(email: "tarabucci@gmail.com") do |u|
  u.name  = "Tara Bucci"
  u.admin = true
end

# Set Tara's temp password. Seeds are idempotent so this resets her password
# to "changeme" on every deploy UNTIL she removes this line (or changes her
# password via /set-password afterwards). Once she changes the password in
# the app, remove this reset so subsequent deploys don't clobber her change.
# TODO: remove when Tara has set her own password in production.
if tara.password_digest.blank?
  tara.update!(password: "changeme", password_confirmation: "changeme")
  puts "Set temporary password for Tara (changeme) — change this via /set-password after signing in."
end

tara.update!(
  location:            "Villanova, PA",
  ntrp_rating:         4.0,
  ntrp_rating_date:    Date.new(2025, 12, 31),
  dynamic_rating:      3.94,
  dynamic_rating_date: Date.new(2026, 2, 26)
)

# --------------------------------------------------------------
# Clean out any old team data from previous seeds
# --------------------------------------------------------------
# Use raw SQL to delete in correct order (child tables first) to avoid
# foreign key constraint errors. This is safer than PRAGMA foreign_keys = OFF.
conn = ActiveRecord::Base.connection

# Get IDs of all teams owned by Tara (plus any old placeholder names)
old_team_names = [ "Quad Squad", "Over Served", "Tri Me", "AGC ACES", "Unmatchables" ]
tara_team_ids = tara.tennis_teams.pluck(:id)
old_team_ids  = TennisTeam.where(name: old_team_names).pluck(:id)
all_cleanup_ids = (tara_team_ids + old_team_ids).uniq

if all_cleanup_ids.any?
  ids = all_cleanup_ids.join(",")
  # Get match IDs for these teams
  match_ids = conn.select_values("SELECT id FROM matches WHERE tennis_team_id IN (#{ids})")

  if match_ids.any?
    mids = match_ids.join(",")
    # Get match_line IDs
    line_ids = conn.select_values("SELECT id FROM match_lines WHERE match_id IN (#{mids})")

    if line_ids.any?
      lids = line_ids.join(",")
      conn.execute("DELETE FROM match_line_players WHERE match_line_id IN (#{lids})")
    end

    conn.execute("DELETE FROM match_lines WHERE match_id IN (#{mids})")
    conn.execute("DELETE FROM availabilities WHERE match_id IN (#{mids})")
    conn.execute("DELETE FROM notifications WHERE match_id IN (#{mids})")

    # Clean up lineups
    lineup_ids = conn.select_values("SELECT id FROM lineups WHERE match_id IN (#{mids})") rescue []
    if lineup_ids.any?
      luids = lineup_ids.join(",")
      conn.execute("DELETE FROM lineup_slots WHERE lineup_id IN (#{luids})")
    end
    conn.execute("DELETE FROM lineups WHERE match_id IN (#{mids})") rescue nil
  end

  conn.execute("DELETE FROM matches WHERE tennis_team_id IN (#{ids})")
  conn.execute("DELETE FROM division_teams WHERE tennis_team_id IN (#{ids})")
  conn.execute("DELETE FROM team_memberships WHERE tennis_team_id IN (#{ids})")
  conn.execute("DELETE FROM notifications WHERE tennis_team_id IN (#{ids})")
  conn.execute("DELETE FROM tennis_teams WHERE id IN (#{ids})")
end

# --------------------------------------------------------------
# Team 1: Kiss My Ace (USTA Adult 40+)
# --------------------------------------------------------------
kiss_my_ace = tara.tennis_teams.create!(
  name:            "Kiss My Ace",
  team_type:       "Adult 40+",
  section:         "Middle States",
  gender:          "F",
  rating:          4.0,
  start_date:      Date.new(2026, 4, 14),
  league_category: "USTA",
  home_court:      "Bryn Mawr Racquet Club, 4 N Warner Ave, Bryn Mawr PA 19010",
  season_name:     "Spring 2026"
)

# Kiss My Ace roster (from TennisLink, Session 7)
kma_roster = [
  [ "Stephanie Giordano",  3.5 ],
  [ "Amanda Neill",        4.0 ],
  [ "Leslie Brinkley",     3.5 ],
  [ "Rebecca Feinberg",    3.5 ],
  [ "Jaclyn Groenen",      4.0 ], # captain
  [ "Lynn Sundblad",       4.0 ],
  [ "Rachel Chadwin",      4.0 ],
  [ "Amanda Neczypor",     3.5 ],
  [ "Helen Lee",           3.5 ],
  [ "Helen He",            4.0 ],
  [ "Sarah Brautigan",     4.0 ],
  [ "Mary Marshall",       4.0 ],
  [ "Alison Vachris",      4.0 ],
  [ "Doris Kerr",          4.0 ],
  [ "Nicole Costelloe",    4.0 ],
  [ "Christina Faidley",   4.0 ],
  [ "Jody Staples",        3.5 ],
  [ "Karli McGill",        4.0 ],
  [ "Kerry McDuffie",      4.0 ],
  [ "Vanessa Halloran",    4.0 ],
  [ "Bridget Hallman",     4.0 ]
]

kma_roster.each do |name, ntrp|
  player = find_or_make_player(name, ntrp: ntrp)
  TeamMembership.find_or_create_by!(user: player, tennis_team: kiss_my_ace) do |m|
    m.role = (name == "Jaclyn Groenen" ? "captain" : "player")
  end
end

# Tara on Kiss My Ace (player)
TeamMembership.find_or_create_by!(user: tara, tennis_team: kiss_my_ace) do |m|
  m.role = "player"
end

# Kiss My Ace — full 8-match schedule from TennisLink
kma_schedule = [
  [ Date.new(2026, 4, 14), "Kinetix Deuces Wild" ],
  [ Date.new(2026, 4, 21), "Unmatchables" ],
  [ Date.new(2026, 5, 5),  "Tennis Addiction" ],
  [ Date.new(2026, 5, 12), "Love Hurts" ],
  [ Date.new(2026, 5, 19), "Kinetix Deuces Wild" ],
  [ Date.new(2026, 6, 2),  "Unmatchables" ],
  [ Date.new(2026, 6, 16), "Tennis Addiction" ],
  [ Date.new(2026, 6, 23), "Love Hurts" ]
]

kma_schedule.each do |date, opp|
  kiss_my_ace.matches.find_or_create_by!(match_date: Time.zone.local(date.year, date.month, date.day, 10, 30)) do |m|
    m.opponent = opp
    m.location = "Bryn Mawr Racquet Club"
    m.match_time = "10:30 AM"
    m.home_away = (opp == "Kinetix Deuces Wild" && date == Date.new(2026, 4, 14)) ? "home" : "away"
    m.notes = (m.home_away == "home") ? "Home" : "Away"
  end
end

# Kiss My Ace — April 14 lineup vs. Kinetix Deuces Wild (from TennisLink, all confirmed)
# This seed always resets the Apr 14 lineup to the canonical 9 slots. If Tara
# edits it via the app, those edits will be overwritten on the next deploy —
# remove this block when Tara starts managing lineups from the app directly.
kma_apr14 = kiss_my_ace.matches.find_by(match_date: Time.zone.local(2026, 4, 14, 10, 30))
if kma_apr14
  kma_lineup = kma_apr14.lineup || kma_apr14.create_lineup!

  # Wipe any stray slots from earlier test sessions
  kma_lineup.lineup_slots.destroy_all

  apr14_slots = [
    { line_type: "singles", position: 1, name: "Jaclyn Groenen"    },
    { line_type: "doubles", position: 1, name: "Alison Vachris"    },
    { line_type: "doubles", position: 1, name: "Tara Bucci"        },
    { line_type: "doubles", position: 2, name: "Amanda Neill"      },
    { line_type: "doubles", position: 2, name: "Rachel Chadwin"    },
    { line_type: "doubles", position: 3, name: "Sarah Brautigan"   },
    { line_type: "doubles", position: 3, name: "Stephanie Giordano" },
    { line_type: "doubles", position: 4, name: "Helen Lee"         },
    { line_type: "doubles", position: 4, name: "Kerry McDuffie"    }
  ]

  apr14_slots.each do |s|
    u = User.find_by(name: s[:name])
    next unless u
    LineupSlot.create!(
      lineup:       kma_lineup,
      user:         u,
      line_type:    s[:line_type],
      position:     s[:position],
      confirmation: "confirmed",
      confirmed_at: Time.current
    )
  end

  kma_lineup.update!(published: true, published_at: Time.current)
  puts "Seeded Kiss My Ace April 14 lineup (#{kma_lineup.lineup_slots.count} slots, all confirmed)"
end

# Kiss My Ace — April 21 lineup vs. Unmatchables (from TennisLink, all confirmed)
# Same pattern as Apr 14: destroy_all + recreate so the canonical state always
# wins. Remove this block when Tara starts managing lineups from the app directly.
kma_apr21 = kiss_my_ace.matches.find_by(match_date: Time.zone.local(2026, 4, 21, 10, 30))
if kma_apr21
  kma_apr21_lineup = kma_apr21.lineup || kma_apr21.create_lineup!
  kma_apr21_lineup.lineup_slots.destroy_all

  apr21_slots = [
    { line_type: "singles", position: 1, name: "Tara Bucci"        },
    { line_type: "doubles", position: 1, name: "Alison Vachris"    },
    { line_type: "doubles", position: 1, name: "Bridget Hallman"   },
    { line_type: "doubles", position: 2, name: "Sarah Brautigan"   },
    { line_type: "doubles", position: 2, name: "Vanessa Halloran"  },
    { line_type: "doubles", position: 3, name: "Lynn Sundblad"     },
    { line_type: "doubles", position: 3, name: "Mary Marshall"     },
    { line_type: "doubles", position: 4, name: "Christina Faidley" },
    { line_type: "doubles", position: 4, name: "Jody Staples"      }
  ]

  apr21_slots.each do |s|
    u = User.find_by(name: s[:name])
    next unless u
    LineupSlot.create!(
      lineup:       kma_apr21_lineup,
      user:         u,
      line_type:    s[:line_type],
      position:     s[:position],
      confirmation: "confirmed",
      confirmed_at: Time.current
    )
  end

  kma_apr21_lineup.update!(published: true, published_at: Time.current)
  puts "Seeded Kiss My Ace April 21 lineup (#{kma_apr21_lineup.lineup_slots.count} slots, all confirmed)"
end

# --------------------------------------------------------------
# Team 2: Pour Decisions (USTA Adult 18+)
# --------------------------------------------------------------
pour_decisions = tara.tennis_teams.create!(
  name:            "Pour Decisions",
  team_type:       "Adult 18+",
  section:         "Middle States",
  gender:          "F",
  rating:          4.0,
  start_date:      Date.new(2026, 4, 17),
  league_category: "USTA",
  home_court:      "Radnor Valley Country Club, 555 Sproul Rd, Villanova PA 19085",
  season_name:     "Spring 2026"
)

pd_roster = [
  [ "Jaclyn Groenen",    4.0 ],
  [ "Lynn Sundblad",     4.0 ], # captain
  [ "Amanda Neill",      4.0 ],
  [ "Rachel Chadwin",    4.0 ],
  [ "Rebecca Feinberg",  3.5 ],
  [ "Helen Lee",         3.5 ],
  [ "Amanda Neczypor",   3.5 ],
  [ "Kerry McDuffie",    4.0 ],
  [ "Nicole Costelloe",  4.0 ],
  [ "Olivia Andrews",    4.0 ],
  [ "Kristin Kobell",    3.5 ],
  [ "Christina Faidley", 3.5 ],
  [ "Lisa Tan",          3.5 ],
  [ "Jody Staples",      3.5 ],
  [ "Karli McGill",      4.0 ],
  [ "Leslie Brinkley",   3.5 ]
]

pd_roster.each do |name, ntrp|
  player = find_or_make_player(name, ntrp: ntrp)
  TeamMembership.find_or_create_by!(user: player, tennis_team: pour_decisions) do |m|
    m.role = (name == "Lynn Sundblad" ? "captain" : "player")
  end
end

TeamMembership.find_or_create_by!(user: tara, tennis_team: pour_decisions) do |m|
  m.role = "player"
end

# Pour Decisions — full 8-match schedule from TennisLink
pd_schedule = [
  [ Date.new(2026, 4, 17), "No Drama Mamas" ],
  [ Date.new(2026, 4, 24), "St. Albans" ],
  [ Date.new(2026, 5, 8),  "UD Smash Squad" ],
  [ Date.new(2026, 5, 15), "Simply Smashing" ],
  [ Date.new(2026, 5, 29), "Merion Cricket 18+" ],
  [ Date.new(2026, 6, 5),  "Philly Cricket" ],
  [ Date.new(2026, 6, 12), "Quad Squad" ],
  [ Date.new(2026, 6, 19), "Kicking Aces" ]
]

pd_schedule.each do |date, opp|
  pour_decisions.matches.find_or_create_by!(match_date: Time.zone.local(date.year, date.month, date.day, 18, 30)) do |m|
    m.opponent = opp
    m.location = "Radnor Valley Country Club"
  end
end

# --------------------------------------------------------------
# Team 3: Philadelphia Country Club #2 (Inter-Club, Cup 6)
# --------------------------------------------------------------
pcc = tara.tennis_teams.create!(
  name:            "Philadelphia Country #2",
  team_type:       "Cup 6 (Monday)",
  section:         "Philadelphia Inter-Club",
  gender:          "F",
  rating:          nil,
  start_date:      Date.new(2026, 4, 27),
  league_category: "Inter-Club",
  home_court:      "Philadelphia Country Club, 1601 Spring Mill Rd, Gladwyne PA 19035",
  season_name:     "Spring 2026"
)

pcc_roster = [
  [ "Joanne Steinberg",  nil ],
  [ "Amanda Neczypor",   3.5 ],
  [ "Jill Kirchner",     3.0 ],
  [ "Laura Zalewski",    3.5 ],
  [ "Lynda Donahue",     nil ],
  [ "Anne Siembieda",    nil ],
  [ "karen ernst",       nil ],
  [ "Robyn Leto",        nil ],
  [ "Ryan Longstreth",   nil ],
  [ "Laurie Nowlan",     nil ]
]

# Note: Jaclyn "Jaci" Groenen is on PCC too (Inter-Club has her name as "Jaci Gronen")
jaci = find_or_make_player("Jaclyn Groenen", ntrp: 4.0)
TeamMembership.find_or_create_by!(user: jaci, tennis_team: pcc) do |m|
  m.role = "player"
end

pcc_roster.each do |name, ntrp|
  player = find_or_make_player(name, ntrp: ntrp)
  TeamMembership.find_or_create_by!(user: player, tennis_team: pcc) do |m|
    m.role = "player"
  end
end

TeamMembership.find_or_create_by!(user: tara, tennis_team: pcc) do |m|
  m.role = "player"
end

# PCC — full 7-match schedule from Inter-Club website (all 10 AM Mondays)
pcc_schedule = [
  [ Date.new(2026, 4, 27), "Laurel Creek #1",        "away" ],
  [ Date.new(2026, 5, 4),  "Waynesborough #3",       "home" ],
  [ Date.new(2026, 5, 11), "Philadelphia Cricket #3", "away" ],
  [ Date.new(2026, 5, 18), "Dupont CC #1",           "home" ],
  [ Date.new(2026, 5, 26), "Delsea #2",              "away" ],
  [ Date.new(2026, 6, 1),  "Overbrook #2",           "home" ],
  [ Date.new(2026, 6, 8),  "West Chester #2",        "away" ]
]

pcc_schedule.each do |date, opp, home_away|
  pcc.matches.find_or_create_by!(match_date: Time.zone.local(date.year, date.month, date.day, 10, 0)) do |m|
    m.opponent = opp
    m.location = home_away == "home" ? "Philadelphia Country Club" : "Away"
    m.notes    = home_away == "home" ? "Home match" : "Away match"
    m.match_time = "10:00 AM"
    m.home_away = home_away
  end
end

# --------------------------------------------------------------
# Team 4: Legacy 2 (Del-Tri Division 4, 2025-26 season — COMPLETED)
# --------------------------------------------------------------
legacy_2 = tara.tennis_teams.create!(
  name:            "Legacy 2",
  team_type:       "Division 4",
  section:         "Del-Tri",
  gender:          "F",
  rating:          nil,
  start_date:      Date.new(2025, 10, 3),
  league_category: "Local",
  home_court:      "Legacy Tennis, 4842 Ridge Ave, Philadelphia PA 19129",
  season_name:     "Fall/Winter 2025-26 (Completed)"
)

legacy_roster = [
  [ "JoAnne Steinberg",       3.0 ], # captain
  [ "Anh Bixby",              4.0 ],
  [ "Rachel Miller",          3.5 ],
  [ "Khue Feigenberg",        3.5 ],
  [ "Rebecca Bramen",         3.0 ],
  [ "Sarah Dougherty",        3.0 ],
  [ "Leilani Schlottfeldt",   3.0 ],
  [ "Lindsey Schontz",        3.0 ],
  [ "Jill Kirchner",          3.0 ],
  [ "Laura Zalewski",         3.5 ]
]

legacy_roster.each do |name, ntrp|
  player = find_or_make_player(name, ntrp: ntrp)
  TeamMembership.find_or_create_by!(user: player, tennis_team: legacy_2) do |m|
    m.role = (name == "JoAnne Steinberg" ? "captain" : "player")
  end
end

TeamMembership.find_or_create_by!(user: tara, tennis_team: legacy_2) do |m|
  m.role = "player"
end

# Legacy 2 — full 18-match schedule with results (season completed)
legacy_schedule = [
  [ "2025-10-03", "Brandywine 5",        "away", "loss",  "2-4" ],
  [ "2025-10-10", "DVTA 3",              "home", "loss",  "2-4" ],
  [ "2025-10-17", "Brandywine 4",        "away", "loss",  "2-4" ],
  [ "2025-10-24", "Tennis Addiction 4",   "home", "tie",   "3-3" ],
  [ "2025-10-31", "Upper Main Line Y 2", "home", "win",   "4-2" ],
  [ "2025-11-07", "Springfield YMCA 3",  "home", "tie",   "3-3" ],
  [ "2025-11-14", "HPTA 6",             "away", "win",   "5-1" ],
  [ "2025-11-21", "Radnor Racquet 3",   "home", "win",   "4-2" ],
  [ "2025-12-05", "Penn Oaks 5",        "away", "win",   "4-2" ],
  [ "2026-01-09", "Brandywine 5",       "home", "tie",   "3-3" ],
  [ "2026-01-16", "DVTA 3",             "away", "win",   "4-2" ],
  [ "2026-01-23", "Brandywine 4",       "home", "win",   "6-0" ],
  [ "2026-01-30", "Tennis Addiction 4",  "away", "win",   "4-2" ],
  [ "2026-02-06", "Upper Main Line Y 2","away", "win",   "4-2" ],
  [ "2026-02-20", "Springfield YMCA 3", "away", "tie",   "3-3" ],
  [ "2026-02-27", "HPTA 6",             "home", "win",   "6-0" ],
  [ "2026-03-06", "Radnor Racquet 3",   "away", "win",   "5-1" ],
  [ "2026-03-13", "Penn Oaks 5",        "home", "win",   "4-2" ]
]

legacy_schedule.each do |date_str, opp, ha, result, score|
  d = Date.parse(date_str)
  legacy_2.matches.find_or_create_by!(match_date: Time.zone.local(d.year, d.month, d.day, 10, 0)) do |m|
    m.opponent = opp
    m.location = (ha == "home") ? "Legacy Tennis" : opp.split(" ").first
    m.home_away = ha
    m.notes = (ha == "home") ? "Home" : "Away"
    m.result = (result == "tie" ? "win" : result)  # Del-Tri ties count as draws, treating as wins for points
    m.score_summary = score
  end
end

# --------------------------------------------------------------
# Tara's match stats (kept from earlier — USTA-focused)
# --------------------------------------------------------------
[
  [ 2026,   5,   5,   0,   12,   10,   2,   83,   55,  28,    0 ],
  [ 2025,  45,  39,   6,  nil,  nil, nil,  nil,  nil, nil,  nil ],
  [ 2024,   9,   5,   4,  nil,  nil, nil,  nil,  nil, nil,  nil ]
].each do |year, mt, mw, ml, st, sw, sl, gt, gw, gl, d|
  tara.tennis_stats.find_or_create_by!(year: year) do |s|
    s.matches_total = mt; s.matches_won = mw; s.matches_lost = ml
    s.sets_total    = st; s.sets_won    = sw; s.sets_lost    = sl
    s.games_total   = gt; s.games_won   = gw; s.games_lost   = gl
    s.defaults      = d
  end
end

# --------------------------------------------------------------
# Division standings for each team
# --------------------------------------------------------------

# Kiss My Ace division (USTA 40+ · 4.0 Women Delches · Sub-Flight 2)
[
  "Kinetix Deuces Wild",
  "Love Hurts",
  "Unmatchables",
  "Tennis Addiction"
].each { |name| DivisionTeam.find_or_create_by!(tennis_team: kiss_my_ace, name: name) }

# Pour Decisions division (USTA 18+ · 4.0 Women Del-Ches · Sub-Flight 1)
[
  "Quad Squad",
  "UD Smash Squad",
  "Kicking Aces",
  "St. Albans",
  "No Drama Mamas",
  "Simply Smashing",
  "Merion Cricket 18+",
  "Philly Cricket"
].each { |name| DivisionTeam.find_or_create_by!(tennis_team: pour_decisions, name: name) }

# PCC division (Inter-Club Cup 6)
[
  "Delsea #2",
  "Dupont CC #1",
  "Laurel Creek #1",
  "Overbrook #2",
  "Philadelphia Cricket #3",
  "Waynesborough #3",
  "West Chester #2"
].each { |name| DivisionTeam.find_or_create_by!(tennis_team: pcc, name: name) }

# Legacy 2 division (Del-Tri Division 4) — with final standings from completed season
# Del-Tri uses POINTS (total games won), not W-L records
# Points stored in wins column, W-L from statistics page in losses column for reference
{
  "DVTA 3"              => 70,
  "Brandywine 5"        => 58,
  "Springfield YMCA 3"  => 56,
  "Brandywine 4"        => 53,
  "Radnor Racquet 3"    => 52,
  "HPTA 6"              => 51,
  "Penn Oaks 5"         => 48,
  "Tennis Addiction 4"   => 45,
  "Upper Main Line Y 2" => 39
}.each do |name, pts|
  DivisionTeam.find_or_create_by!(tennis_team: legacy_2, name: name) do |dt|
    dt.wins = pts
    dt.losses = 0
  end
end

# Generate join codes for all teams
TennisTeam.where(join_code: nil).find_each(&:ensure_join_code!)

puts "✓ Seeded: #{TennisTeam.count} teams, #{User.count} users, #{Match.count} matches, #{DivisionTeam.count} division opponents"
