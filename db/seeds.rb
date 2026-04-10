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
# Disable foreign key checks during cleanup so destroy_all works
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")

# Remove old team names that were placeholders before we had real data.
old_team_names = [ "Quad Squad", "Over Served", "Tri Me", "AGC ACES", "Unmatchables" ]
TennisTeam.where(name: old_team_names).each do |team|
  team.matches.each { |m| m.match_lines.each { |l| l.match_line_players.delete_all }; m.match_lines.delete_all; m.availabilities.delete_all }
  team.matches.delete_all
  team.team_memberships.delete_all
  team.destroy
end

# Remove any old teams owned by Tara so seeds is idempotent
tara.tennis_teams.each do |team|
  team.matches.each { |m| m.match_lines.each { |l| l.match_line_players.delete_all }; m.match_lines.delete_all; m.availabilities.delete_all }
  team.matches.delete_all
  team.team_memberships.delete_all
  team.destroy
end

ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")

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
  kiss_my_ace.matches.find_or_create_by!(match_date: Time.zone.local(date.year, date.month, date.day, 19, 0)) do |m|
    m.opponent = opp
    m.location = "Bryn Mawr Racquet Club"
  end
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

puts "✓ Seeded: #{TennisTeam.count} teams, #{User.count} users, #{Match.count} matches"
