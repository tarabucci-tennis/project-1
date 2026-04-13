# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_13_120000) do
  create_table "availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.string "message"
    t.string "status", default: "no_response", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["match_id"], name: "index_availabilities_on_match_id"
    t.index ["user_id", "match_id"], name: "index_availabilities_on_user_id_and_match_id", unique: true
    t.index ["user_id"], name: "index_availabilities_on_user_id"
  end

  create_table "division_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "losses", default: 0, null: false
    t.string "name", null: false
    t.integer "position"
    t.integer "tennis_team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wins", default: 0, null: false
    t.index ["tennis_team_id", "name"], name: "index_division_teams_on_tennis_team_id_and_name", unique: true
    t.index ["tennis_team_id"], name: "index_division_teams_on_tennis_team_id"
  end

  create_table "lineup_slots", force: :cascade do |t|
    t.string "confirmation", default: "pending", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "line_type", null: false
    t.integer "lineup_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["lineup_id", "user_id"], name: "index_lineup_slots_on_lineup_id_and_user_id", unique: true
    t.index ["lineup_id"], name: "index_lineup_slots_on_lineup_id"
    t.index ["user_id"], name: "index_lineup_slots_on_user_id"
  end

  create_table "lineups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_lineups_on_match_id", unique: true
  end

  create_table "match_line_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_line_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["match_line_id", "user_id"], name: "index_match_line_players_on_match_line_id_and_user_id", unique: true
    t.index ["match_line_id"], name: "index_match_line_players_on_match_line_id"
    t.index ["user_id"], name: "index_match_line_players_on_user_id"
  end

  create_table "match_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "line_type", null: false
    t.integer "match_id", null: false
    t.integer "position", null: false
    t.string "result"
    t.string "set1_score"
    t.string "set2_score"
    t.string "set3_score"
    t.datetime "updated_at", null: false
    t.index ["match_id", "position"], name: "index_match_lines_on_match_id_and_position", unique: true
    t.index ["match_id"], name: "index_match_lines_on_match_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "home_away"
    t.string "location"
    t.datetime "match_date", null: false
    t.string "match_time"
    t.text "notes"
    t.string "opponent"
    t.string "result"
    t.string "score_summary"
    t.integer "tennis_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tennis_team_id", "match_date"], name: "index_matches_on_tennis_team_id_and_match_date"
    t.index ["tennis_team_id"], name: "index_matches_on_tennis_team_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.string "body", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "match_id", null: false
    t.boolean "read", default: false, null: false
    t.integer "tennis_team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["match_id"], name: "index_notifications_on_match_id"
    t.index ["tennis_team_id"], name: "index_notifications_on_tennis_team_id"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "team_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "event_date", null: false
    t.string "kind", null: false
    t.string "location"
    t.text "notes"
    t.string "start_time"
    t.integer "tennis_team_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["tennis_team_id", "event_date"], name: "index_team_events_on_tennis_team_id_and_event_date"
    t.index ["tennis_team_id"], name: "index_team_events_on_tennis_team_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "notification_preference", default: "every_update", null: false
    t.string "role", default: "player", null: false
    t.integer "tennis_team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["tennis_team_id"], name: "index_team_memberships_on_tennis_team_id"
    t.index ["user_id", "tennis_team_id"], name: "index_team_memberships_on_user_id_and_tennis_team_id", unique: true
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "tennis_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "defaults"
    t.integer "games_lost"
    t.integer "games_total"
    t.integer "games_won"
    t.integer "matches_lost"
    t.integer "matches_total"
    t.integer "matches_won"
    t.integer "sets_lost"
    t.integer "sets_total"
    t.integer "sets_won"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "year"
    t.index ["user_id"], name: "index_tennis_stats_on_user_id"
  end

  create_table "tennis_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "gender"
    t.string "home_court"
    t.string "join_code"
    t.string "league_category", default: "USTA", null: false
    t.string "name"
    t.decimal "rating"
    t.string "season_name"
    t.string "section"
    t.date "start_date"
    t.string "team_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["join_code"], name: "index_tennis_teams_on_join_code", unique: true
    t.index ["league_category"], name: "index_tennis_teams_on_league_category"
    t.index ["user_id"], name: "index_tennis_teams_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.decimal "dynamic_rating"
    t.date "dynamic_rating_date"
    t.string "email"
    t.string "location"
    t.string "name"
    t.decimal "ntrp_rating"
    t.date "ntrp_rating_date"
    t.string "password_digest"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "availabilities", "matches"
  add_foreign_key "availabilities", "users"
  add_foreign_key "division_teams", "tennis_teams"
  add_foreign_key "lineup_slots", "lineups"
  add_foreign_key "lineup_slots", "users"
  add_foreign_key "lineups", "matches"
  add_foreign_key "match_line_players", "match_lines"
  add_foreign_key "match_line_players", "users"
  add_foreign_key "match_lines", "matches"
  add_foreign_key "matches", "tennis_teams"
  add_foreign_key "notifications", "matches"
  add_foreign_key "notifications", "tennis_teams"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "team_events", "tennis_teams"
  add_foreign_key "team_memberships", "tennis_teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "tennis_stats", "users"
  add_foreign_key "tennis_teams", "users"
end
