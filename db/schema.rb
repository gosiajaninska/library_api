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

ActiveRecord::Schema[8.1].define(version: 2026_11_06_103113) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "readers", force: :cascade do |t|
    t.string "card_number", null: false
    t.citext "email", null: false
    t.string "full_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_number"], name: "index_readers_on_card_number", unique: true
    t.index ["email"], name: "index_readers_on_email", unique: true
    t.check_constraint "btrim(email::text) <> ''::text", name: "readers_email_not_blank"
    t.check_constraint "btrim(full_name::text) <> ''::text", name: "readers_full_name_not_blank"
    t.check_constraint "card_number::text ~ '^[0-9]{6}$'::text", name: "readers_card_number_format"
  end
end
