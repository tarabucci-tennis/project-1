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

# Teams
[
  [ "Quad Squad",    "Adult 18+",     "Middle States", "F", 4.0, "2025-11-13" ],
  [ "Over Served",   "Adult 40+",     "Middle States", "F", 4.0, "2025-11-12" ],
  [ "Tri Me",        "Tri-Level 18+", "Middle States", "F", 4.0, "2025-09-03" ],
  [ "AGC ACES",      "Tri-Level 18+", "Middle States", "F", 4.5, "2025-09-03" ],
  [ "Unmatchables",  "Adult 40+",     "Middle States", "F", 3.5, "2025-06-18" ]
].each do |name, type, section, gender, rating, start|
  tara.tennis_teams.find_or_create_by!(name: name) do |t|
    t.team_type = type
    t.section   = section
    t.gender    = gender
    t.rating    = rating
    t.start_date = Date.parse(start)
  end
end

# Match stats
# Note: sets/games for 2024–2025 were unclear in the source data;
# fill them in from your USTA Connect page via the Players admin panel.
[
  # year  m_tot  m_w  m_l  s_tot  s_w  s_l  g_tot  g_w  g_l  defaults
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

# Jody has no email yet — Tara will add it from the Players admin panel
jody = User.find_or_create_by!(name: "Jody Staples", email: nil) do |u|
  u.admin = false
end

# =====================================================
# Teams, Rosters, Schedule & Availability
# =====================================================

# --- Quad Squad ---
quad_squad = Team.find_or_create_by!(name: "Quad Squad") do |t|
  t.team_type = "Adult 18+"
  t.section   = "Middle States"
  t.gender    = "F"
  t.rating    = 4.0
  t.captain   = tara
end

quad_roster = [
  [ "Tara Bucci",        "captain",    tara ],
  [ "Jody Staples",      "co-captain", jody ],
  [ "Helen He",          "player",     nil ],
  [ "Nicole Costelloe",  "player",     nil ],
  [ "Sheryl Reidenbach", "player",     nil ],
  [ "Ada Martini",       "player",     nil ],
  [ "Kerri Klein",       "player",     nil ],
  [ "Demi Lin",          "player",     nil ],
  [ "Lauren Murray",     "player",     nil ],
  [ "Sarah Chen",        "player",     nil ],
  [ "Katie Walsh",       "player",     nil ],
  [ "Megan Riley",       "player",     nil ],
  [ "Priya Patel",       "player",     nil ],
  [ "Jen Marconi",       "player",     nil ],
  [ "Lisa Brennan",      "player",     nil ],
  [ "Courtney Fox",      "player",     nil ],
  [ "Amanda Sullivan",   "player",     nil ]
]

quad_players = quad_roster.map do |name, role, user|
  quad_squad.team_players.find_or_create_by!(player_name: name) do |p|
    p.role = role
    p.user = user
  end
end

# Quad Squad schedule — spring 2026
quad_matches_data = [
  [ "2026-04-10", "6:30 PM", "Net Gains",         "home", "Gulph Mills Tennis Club" ],
  [ "2026-04-17", "6:30 PM", "Racquet Science",    "away", "Merion Cricket Club" ],
  [ "2026-04-24", "6:30 PM", "Smash Sisters",      "home", "Gulph Mills Tennis Club" ],
  [ "2026-05-01", "6:30 PM", "Court Crushers",     "away", "Philadelphia Cricket Club" ],
  [ "2026-05-08", "6:30 PM", "The Volley Llamas",  "home", "Gulph Mills Tennis Club" ],
  [ "2026-05-15", "6:30 PM", "Drop Shot Divas",    "away", "Aronimink Golf Club" ],
  [ "2026-05-22", "6:30 PM", "Ace Ventura",        "home", "Gulph Mills Tennis Club" ],
  [ "2026-05-29", "6:30 PM", "Baseline Babes",     "away", "Waynesborough CC" ],
  [ "2026-03-12", "6:30 PM", "Net Gains",          "away", "Merion Cricket Club" ],
  [ "2026-03-26", "6:30 PM", "Racquet Science",    "home", "Gulph Mills Tennis Club" ]
]

quad_matches = quad_matches_data.map do |date, time, opp, ha, loc|
  quad_squad.scheduled_matches.find_or_create_by!(match_date: Date.parse(date), opponent_team: opp) do |m|
    m.match_time = time
    m.home_away  = ha
    m.location   = loc
  end
end

# Seed availability for upcoming matches
upcoming_quad = quad_matches.select { |m| m.match_date >= Date.current }.first(3)
upcoming_quad.each_with_index do |match, mi|
  quad_players.each_with_index do |player, pi|
    status = case
    when pi < 9 then "confirmed"
    when pi < 12 then "unavailable"
    when pi == 12 then "custom"
    else "pending"
    end

    match.player_availabilities.find_or_create_by!(team_player: player) do |a|
      a.status  = status
      a.message = "Yaaass 😄" if status == "custom"
    end
  end
end

# Seed lineup for first upcoming match
first_upcoming = upcoming_quad.first
if first_upcoming
  [
    [ "1S", [ quad_players[0] ] ],                     # Tara
    [ "1D", [ quad_players[2], quad_players[3] ] ],    # Helen & Nicole
    [ "2D", [ quad_players[4], quad_players[5] ] ],    # Sheryl & Ada
    [ "3D", [ quad_players[6], quad_players[7] ] ],    # Kerri & Demi
    [ "4D", [ quad_players[8], quad_players[9] ] ]     # Lauren & Sarah
  ].each do |pos, players|
    players.each do |p|
      first_upcoming.lineup_slots.find_or_create_by!(team_player: p, position: pos)
    end
  end
end

# --- Over Served ---
over_served = Team.find_or_create_by!(name: "Over Served") do |t|
  t.team_type = "Adult 40+"
  t.section   = "Middle States"
  t.gender    = "F"
  t.rating    = 4.0
  t.captain   = tara
end

os_roster = [
  [ "Tara Bucci",       "captain",    tara ],
  [ "Jody Staples",     "co-captain", jody ],
  [ "Nicole Costelloe", "player",     nil ],
  [ "Carissa McIlwain", "player",     nil ],
  [ "Olivia Andrews",   "player",     nil ],
  [ "Candice Holbert",  "player",     nil ],
  [ "Meghann Reddy",    "player",     nil ],
  [ "Beth Donovan",     "player",     nil ],
  [ "Robin Sawyer",     "player",     nil ],
  [ "Steph Morris",     "player",     nil ],
  [ "Diana Kowalski",   "player",     nil ],
  [ "Marie Chen",       "player",     nil ],
  [ "Val Ricci",        "player",     nil ]
]

os_roster.each do |name, role, user|
  over_served.team_players.find_or_create_by!(player_name: name) do |p|
    p.role = role
    p.user = user
  end
end

os_matches_data = [
  [ "2026-04-14", "10:00 AM", "Wine & Whine",       "home", "Gulph Mills Tennis Club" ],
  [ "2026-04-21", "10:00 AM", "40 Love",            "away", "Radnor Racquet Club" ],
  [ "2026-04-28", "10:00 AM", "Game Set Merlot",    "home", "Gulph Mills Tennis Club" ],
  [ "2026-05-05", "10:00 AM", "No Ad-vantage",      "away", "Waynesborough CC" ],
  [ "2026-05-12", "10:00 AM", "Serve-ivors",        "home", "Gulph Mills Tennis Club" ],
  [ "2026-03-10", "10:00 AM", "Wine & Whine",       "away", "Radnor Racquet Club" ],
  [ "2026-03-24", "10:00 AM", "40 Love",            "home", "Gulph Mills Tennis Club" ]
]

os_matches_data.each do |date, time, opp, ha, loc|
  over_served.scheduled_matches.find_or_create_by!(match_date: Date.parse(date), opponent_team: opp) do |m|
    m.match_time = time
    m.home_away  = ha
    m.location   = loc
  end
end
