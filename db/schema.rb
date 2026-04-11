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

ActiveRecord::Schema[8.1].define(version: 2026_04_11_000000) do
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
    t.string "password_digest"
    t.date "dynamic_rating_date"
    t.string "email"
    t.string "location"
    t.string "name"
    t.decimal "ntrp_rating"
    t.date "ntrp_rating_date"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "tennis_stats", "users"
  add_foreign_key "tennis_teams", "users"
end
