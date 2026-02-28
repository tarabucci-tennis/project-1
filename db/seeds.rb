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
User.find_or_create_by!(name: "Jody Staples", email: nil) do |u|
  u.admin = false
end
