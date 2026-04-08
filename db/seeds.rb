# =====================================================
# Court Report - Seeds
# =====================================================

# --- Captains ---
jaclyn = User.find_or_create_by!(email: "jaclyn@courtreport.com") do |u|
  u.name = "Jaclyn Groenen"
  u.password = "tennis2026"
  u.ntrp_rating = 4.0
  u.location = "Bryn Mawr, PA"
end

lynn = User.find_or_create_by!(email: "lynn@courtreport.com") do |u|
  u.name = "Lynn Sundblad"
  u.password = "tennis2026"
  u.ntrp_rating = 4.0
end

# --- Tara (super admin) ---
tara = User.find_or_create_by!(email: "tarabucci@gmail.com") do |u|
  u.name = "Tara Bucci"
  u.password = "tennis2026"
end
tara.update!(
  super_admin: true,
  admin: true,
  ntrp_rating: 4.0,
  ntrp_rating_date: Date.new(2025, 12, 31),
  dynamic_rating: 3.9413,
  dynamic_rating_date: Date.new(2026, 4, 2),
  location: "Villanova, PA"
)

# =====================================================
# KISS MY ACE - USTA 4.0 Women's
# =====================================================
kma = Team.find_or_create_by!(name: "Kiss My Ace") do |t|
  t.captain = jaclyn
  t.league = "USTA"
  t.team_type = "Adult 18+ 4.0"
  t.section = "Middle States"
  t.gender = "F"
  t.rating = 4.0
  t.home_court = "Bryn Mawr Racquet Club · 4 N Warner Ave, Bryn Mawr"
  t.join_code = "kiss-my-ace"
end

kma_players = [
  ["Jaclyn Groenen",     "captain", jaclyn, 4.0],
  ["Tara Bucci",         "player",  tara,   4.0],
  ["Stephanie Giordano", "player",  nil,    3.5],
  ["Amanda Neill",       "player",  nil,    4.0],
  ["Leslie Brinkley",    "player",  nil,    3.5],
  ["Rebecca Feinberg",   "player",  nil,    3.5],
  ["Lynn Sundblad",      "player",  lynn,   4.0],
  ["Rachel Chadwin",     "player",  nil,    4.0],
  ["Amanda Neczypor",    "player",  nil,    3.5],
  ["Helen Lee",          "player",  nil,    3.5],
  ["Helen He",           "player",  nil,    4.0],
  ["Sarah Brautigan",    "player",  nil,    4.0],
  ["Mary Marshall",      "player",  nil,    3.5],
  ["Alison Vachris",     "player",  nil,    4.0],
  ["Doris Kerr",         "player",  nil,    4.0],
  ["Nicole Costelloe",   "player",  nil,    4.0],
  ["Christina Faidley",  "player",  nil,    3.5],
  ["Jody Staples",       "player",  nil,    3.5],
  ["Karli McGill",       "player",  nil,    4.0],
  ["Kerry McDuffie",     "player",  nil,    4.0],
  ["Vanessa Halloran",   "player",  nil,    4.0],
  ["Bridget Hallman",    "player",  nil,    4.0]
].map do |name, role, user, rating|
  tp = kma.team_players.find_or_create_by!(player_name: name) do |p|
    p.role = role
    p.user = user
  end
  # Set NTRP rating on user if linked
  if user && rating
    user.update!(ntrp_rating: rating) unless user.ntrp_rating
  end
  tp
end

# Kiss My Ace Schedule - Spring 2026
[
  ["2026-04-14", "Kinetix Deuces Wild", "home", "Bryn Mawr Racquet Club · 4 N Warner Ave, Bryn Mawr"],
  ["2026-04-21", "Unmatchables",        "away", "Conestoga Swim Club · 501 Sproul Rd, Villanova"],
  ["2026-05-05", "Tennis Addiction",     "away", "Tennis Addiction Sports Club · 202 Philips Rd, Exton"],
  ["2026-05-12", "Love Hurts",          "away", "Upper Main Line YMCA · 1416 Berwyn Paoli Rd, Berwyn"],
  ["2026-05-19", "Kinetix Deuces Wild", "away", "Kinetix Tennis · 951 N Park Ave, Norristown"],
  ["2026-06-02", "Unmatchables",        "home", "Bryn Mawr Racquet Club · 4 N Warner Ave, Bryn Mawr"],
  ["2026-06-16", "Tennis Addiction",     "home", "Bryn Mawr Racquet Club · 4 N Warner Ave, Bryn Mawr"],
  ["2026-06-23", "Love Hurts",          "home", "Bryn Mawr Racquet Club · 4 N Warner Ave, Bryn Mawr"]
].each do |date, opp, ha, loc|
  match = kma.scheduled_matches.find_or_create_by!(match_date: Date.parse(date), opponent_team: opp) do |m|
    m.home_away = ha
    m.location = loc
  end
  # Create pending availability for all players
  kma_players.each do |tp|
    match.player_availabilities.find_or_create_by!(team_player: tp) do |a|
      a.status = "pending"
    end
  end
end

# =====================================================
# POUR DECISIONS - USTA 4.0 Women's
# =====================================================
pd = Team.find_or_create_by!(name: "Pour Decisions") do |t|
  t.captain = lynn
  t.league = "USTA"
  t.team_type = "Adult 18+ 4.0"
  t.section = "Middle States"
  t.gender = "F"
  t.rating = 4.0
  t.home_court = "Radnor Valley Country Club · 555 Sproul Rd, Villanova"
  t.join_code = "pour-decisions"
end

pd_players = [
  ["Lynn Sundblad",      "captain", lynn,   4.0],
  ["Jaclyn Groenen",     "player",  jaclyn, 4.0],
  ["Tara Bucci",         "player",  tara,   4.0],
  ["Amanda Neill",       "player",  nil,    4.0],
  ["Rachel Chadwin",     "player",  nil,    4.0],
  ["Rebecca Feinberg",   "player",  nil,    3.5],
  ["Helen Lee",          "player",  nil,    3.5],
  ["Amanda Neczypor",    "player",  nil,    3.5],
  ["Kerry McDuffie",     "player",  nil,    4.0],
  ["Nicole Costelloe",   "player",  nil,    4.0],
  ["Olivia Andrews",     "player",  nil,    4.0],
  ["Kristin Kobell",     "player",  nil,    4.0],
  ["Christina Faidley",  "player",  nil,    3.5],
  ["Lisa Tan",           "player",  nil,    3.5],
  ["Jody Staples",       "player",  nil,    3.5],
  ["Karli McGill",       "player",  nil,    4.0]
].map do |name, role, user, rating|
  tp = pd.team_players.find_or_create_by!(player_name: name) do |p|
    p.role = role
    p.user = user
  end
  if user && rating
    user.update!(ntrp_rating: rating) unless user.ntrp_rating
  end
  tp
end

# Pour Decisions Schedule - Spring 2026
[
  ["2026-04-13", "IKST Gulph Mills",          "home", "Radnor Valley Country Club · 555 Sproul Rd, Villanova"],
  ["2026-04-27", "Saint Albans Swim & Tennis", "away", "Saint Albans Swim and Tennis Club"],
  ["2026-05-08", "UD Smash Squad",            "away", "Upper Dublin Sports Center"],
  ["2026-05-15", "Simply Smashing",           "home", "Radnor Valley Country Club · 555 Sproul Rd, Villanova"],
  ["2026-05-29", "Merion Cricket 18+",        "away", "The Merion Cricket Club"],
  ["2026-06-05", "Philly Cricket",            "home", "Radnor Valley Country Club · 555 Sproul Rd, Villanova"],
  ["2026-06-12", "Quad Squad",                "home", "Radnor Valley Country Club · 555 Sproul Rd, Villanova"],
  ["2026-06-19", "Kicking Aces",              "home", "Radnor Valley Country Club · 555 Sproul Rd, Villanova"]
].each do |date, opp, ha, loc|
  match = pd.scheduled_matches.find_or_create_by!(match_date: Date.parse(date), opponent_team: opp) do |m|
    m.home_away = ha
    m.location = loc
  end
  pd_players.each do |tp|
    match.player_availabilities.find_or_create_by!(team_player: tp) do |a|
      a.status = "pending"
    end
  end
end

puts "Seeded: Jaclyn (captain KMA), Lynn (captain PD), Tara (super admin)"
puts "Join Kiss My Ace: /join/kiss-my-ace"
puts "Join Pour Decisions: /join/pour-decisions"
