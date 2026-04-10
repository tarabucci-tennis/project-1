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
  [ "Philadelphia Country #2", "Cup 6 (Monday)", "Philadelphia Inter-Club", "F", nil,  "2026-04-27" ],
  [ "Pour Decisions",          "Adult 18+",      "Middle States",           "F", 4.0,  "2026-04-17" ],
  [ "Kiss My Ace",             "Adult 40+",      "Middle States",           "F", 4.0,  "2026-04-14" ],
  [ "Quad Squad",              "Adult 18+",      "Middle States",           "F", 4.0,  "2025-11-13" ],
  [ "Over Served",             "Adult 40+",      "Middle States",           "F", 4.0,  "2025-11-12" ],
  [ "Legacy 2",                "Division 4",     "Del-Tri",                 "F", nil,  "2025-10-03" ],
  [ "Tri Me",                  "Tri-Level 18+",  "Middle States",           "F", 4.0,  "2025-09-03" ],
  [ "AGC ACES",                "Tri-Level 18+",  "Middle States",           "F", 4.5,  "2025-09-03" ],
  [ "Unmatchables",            "Adult 40+",      "Middle States",           "F", 3.5,  "2025-06-18" ]
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

# Match results
pour_decisions = tara.tennis_teams.find_by(name: "Pour Decisions")
if pour_decisions && pour_decisions.tennis_matches.empty?
  [
    [ "2026-04-17", "Doubles", "Aronimink TC",       "Home", "W", "6-3, 6-2",  "Jody Staples",  "K. Smith / L. Davis",  1 ],
    [ "2026-04-24", "Doubles", "Merion Cricket Club", "Away", "W", "6-4, 7-5",  "Jody Staples",  "A. Park / M. Chen",    2 ],
    [ "2026-05-01", "Doubles", "Philadelphia CC #3",  "Home", "W", "6-1, 6-4",  "Jody Staples",  "R. Thompson / S. Lee", 3 ],
  ].each do |date, type, opp, loc, res, score, partner, opps, court|
    pour_decisions.tennis_matches.create!(
      match_date: Date.parse(date), match_type: type, opponent_team: opp,
      location: loc, result: res, score: score, partner: partner,
      opponent_players: opps, court_number: court
    )
  end
end

kiss_my_ace = tara.tennis_teams.find_by(name: "Kiss My Ace")
if kiss_my_ace && kiss_my_ace.tennis_matches.empty?
  [
    [ "2026-04-14", "Doubles", "Gulph Mills #2",     "Away", "W", "6-2, 6-3", "M. Johnson",   "P. White / J. Green",   1 ],
    [ "2026-04-21", "Doubles", "Radnor Racquet",     "Home", "L", "4-6, 3-6", "M. Johnson",   "T. Brown / K. Wilson",  2 ],
    [ "2026-04-28", "Doubles", "Waynesborough CC",   "Home", "W", "7-5, 6-4", "M. Johnson",   "D. Martin / C. Hall",   1 ],
  ].each do |date, type, opp, loc, res, score, partner, opps, court|
    kiss_my_ace.tennis_matches.create!(
      match_date: Date.parse(date), match_type: type, opponent_team: opp,
      location: loc, result: res, score: score, partner: partner,
      opponent_players: opps, court_number: court
    )
  end
end

quad_squad = tara.tennis_teams.find_by(name: "Quad Squad")
if quad_squad && quad_squad.tennis_matches.empty?
  [
    [ "2025-11-13", "Doubles", "Germantown Academy",  "Away", "W", "6-4, 6-3", "Jody Staples", "L. Adams / R. Clark",  1 ],
    [ "2025-11-20", "Doubles", "Cynwyd Club",         "Home", "W", "6-2, 7-6", "Jody Staples", "B. Lewis / N. Walker", 2 ],
    [ "2025-12-04", "Doubles", "Bala Golf Club",      "Away", "L", "3-6, 6-7", "Jody Staples", "S. Allen / H. Young",  1 ],
    [ "2025-12-11", "Doubles", "Philadelphia CC #1",  "Home", "W", "6-1, 6-3", "Jody Staples", "M. King / E. Wright",  3 ],
  ].each do |date, type, opp, loc, res, score, partner, opps, court|
    quad_squad.tennis_matches.create!(
      match_date: Date.parse(date), match_type: type, opponent_team: opp,
      location: loc, result: res, score: score, partner: partner,
      opponent_players: opps, court_number: court
    )
  end
end

over_served = tara.tennis_teams.find_by(name: "Over Served")
if over_served && over_served.tennis_matches.empty?
  [
    [ "2025-11-12", "Doubles", "Haverford TC",       "Home", "W", "6-3, 6-1", "C. Rivera",    "J. Scott / P. Adams",  1 ],
    [ "2025-11-19", "Doubles", "Lower Merion TC",    "Away", "W", "7-5, 6-2", "C. Rivera",    "A. Turner / K. Hill",  2 ],
    [ "2025-12-03", "Doubles", "Bryn Mawr Club",     "Home", "W", "6-4, 6-4", "C. Rivera",    "L. Moore / D. Taylor", 1 ],
  ].each do |date, type, opp, loc, res, score, partner, opps, court|
    over_served.tennis_matches.create!(
      match_date: Date.parse(date), match_type: type, opponent_team: opp,
      location: loc, result: res, score: score, partner: partner,
      opponent_players: opps, court_number: court
    )
  end
end

philly_country = tara.tennis_teams.find_by(name: "Philadelphia Country #2")
if philly_country && philly_country.tennis_matches.empty?
  [
    [ "2026-04-27", "Doubles", "Aronimink TC #2",    "Home", "W", "6-2, 6-4", "S. Martinez",  "J. Lee / R. Patel",    1 ],
  ].each do |date, type, opp, loc, res, score, partner, opps, court|
    philly_country.tennis_matches.create!(
      match_date: Date.parse(date), match_type: type, opponent_team: opp,
      location: loc, result: res, score: score, partner: partner,
      opponent_players: opps, court_number: court
    )
  end
end

# Jody has no email yet — Tara will add it from the Players admin panel
User.find_or_create_by!(name: "Jody Staples", email: nil) do |u|
  u.admin = false
end
