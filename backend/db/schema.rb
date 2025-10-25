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

ActiveRecord::Schema[8.0].define(version: 2025_10_25_151707) do
  create_table "devices", force: :cascade do |t|
    t.string "device_id", null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "guest_user_id"
    t.string "device_fingerprint"
    t.string "stripe_customer_id"
    t.index ["device_fingerprint"], name: "index_devices_on_device_fingerprint"
    t.index ["device_id"], name: "index_devices_on_device_id", unique: true
    t.index ["guest_user_id"], name: "index_devices_on_guest_user_id"
    t.index ["last_seen_at"], name: "index_devices_on_last_seen_at"
  end

  create_table "guest_users", force: :cascade do |t|
    t.string "device_fingerprint", null: false
    t.integer "remaining_uses", default: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_fingerprint"], name: "index_guest_users_on_device_fingerprint", unique: true
  end

  create_table "users_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "status", default: "unpaid", null: false
    t.datetime "verified_at"
    t.datetime "last_login_at"
    t.index ["email"], name: "index_users_tables_on_email", unique: true
  end

  add_foreign_key "devices", "guest_users"
end
