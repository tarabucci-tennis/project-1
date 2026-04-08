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

ActiveRecord::Schema[8.1].define(version: 2026_04_08_100006) do
  create_table "captain_notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "scheduled_match_id", null: false
    t.integer "team_player_id", null: false
    t.string "event_type", null: false
    t.string "message"
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "read"], name: "index_captain_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_captain_notifications_on_user_id"
    t.index ["scheduled_match_id"], name: "index_captain_notifications_on_scheduled_match_id"
    t.index ["team_player_id"], name: "index_captain_notifications_on_team_player_id"
  end

  create_table "lineup_slots", force: :cascade do |t|
    t.integer "scheduled_match_id", null: false
    t.integer "team_player_id", null: false
    t.string "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confirmed", default: false
    t.string "confirmation_message"
    t.datetime "confirmed_at"
    t.index ["scheduled_match_id", "position", "team_player_id"], name: "idx_lineup_match_position_player", unique: true
    t.index ["scheduled_match_id"], name: "index_lineup_slots_on_scheduled_match_id"
    t.index ["team_player_id"], name: "index_lineup_slots_on_team_player_id"
  end

  create_table "match_scores", force: :cascade do |t|
    t.integer "scheduled_match_id", null: false
    t.string "position", null: false
    t.integer "player1_id"
    t.integer "player2_id"
    t.string "opponent1_name"
    t.string "opponent2_name"
    t.string "set1_score"
    t.string "set2_score"
    t.string "set3_score"
    t.string "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player1_id"], name: "index_match_scores_on_player1_id"
    t.index ["player2_id"], name: "index_match_scores_on_player2_id"
    t.index ["scheduled_match_id", "position"], name: "index_match_scores_on_scheduled_match_id_and_position", unique: true
    t.index ["scheduled_match_id"], name: "index_match_scores_on_scheduled_match_id"
  end

  create_table "player_availabilities", force: :cascade do |t|
    t.integer "scheduled_match_id", null: false
    t.integer "team_player_id", null: false
    t.string "status", default: "pending", null: false
    t.string "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_match_id", "team_player_id"], name: "idx_availability_match_player", unique: true
    t.index ["scheduled_match_id"], name: "index_player_availabilities_on_scheduled_match_id"
    t.index ["team_player_id"], name: "index_player_availabilities_on_team_player_id"
  end

  create_table "scheduled_matches", force: :cascade do |t|
    t.integer "team_id", null: false
    t.date "match_date", null: false
    t.string "match_time"
    t.string "opponent_team", null: false
    t.string "home_away", default: "home"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "team_result"
    t.integer "courts_won", default: 0
    t.integer "courts_lost", default: 0
    t.index ["team_id", "match_date"], name: "index_scheduled_matches_on_team_id_and_match_date"
    t.index ["team_id"], name: "index_scheduled_matches_on_team_id"
  end

  create_table "team_players", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "user_id"
    t.string "player_name", null: false
    t.string "role", default: "player", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "player_name"], name: "index_team_players_on_team_id_and_player_name", unique: true
    t.index ["team_id"], name: "index_team_players_on_team_id"
    t.index ["user_id"], name: "index_team_players_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.string "team_type"
    t.string "section"
    t.string "gender"
    t.decimal "rating"
    t.integer "captain_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "league"
    t.string "home_court"
    t.string "join_code"
    t.string "usta_team_number"
    t.index ["captain_id"], name: "index_teams_on_captain_id"
    t.index ["join_code"], name: "index_teams_on_join_code", unique: true
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
    t.string "name"
    t.decimal "rating"
    t.string "section"
    t.date "start_date"
    t.string "team_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
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
    t.datetime "updated_at", null: false
    t.string "notification_preference"
    t.string "password_digest"
    t.string "phone"
    t.string "invite_token"
    t.datetime "invited_at"
    t.boolean "super_admin", default: false, null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invite_token"], name: "index_users_on_invite_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "captain_notifications", "scheduled_matches"
  add_foreign_key "captain_notifications", "team_players"
  add_foreign_key "captain_notifications", "users"
  add_foreign_key "lineup_slots", "scheduled_matches"
  add_foreign_key "lineup_slots", "team_players"
  add_foreign_key "match_scores", "scheduled_matches"
  add_foreign_key "match_scores", "team_players", column: "player1_id"
  add_foreign_key "match_scores", "team_players", column: "player2_id"
  add_foreign_key "player_availabilities", "scheduled_matches"
  add_foreign_key "player_availabilities", "team_players"
  add_foreign_key "scheduled_matches", "teams"
  add_foreign_key "team_players", "teams"
  add_foreign_key "team_players", "users"
  add_foreign_key "teams", "users", column: "captain_id"
  add_foreign_key "tennis_stats", "users"
  add_foreign_key "tennis_teams", "users"
end
