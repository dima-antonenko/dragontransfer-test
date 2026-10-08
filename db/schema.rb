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

ActiveRecord::Schema[8.1].define(version: 2026_10_08_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "orders", force: :cascade do |t|
    t.string "external_id"
    t.string "status", default: "NEW", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.string "phone_number", null: false
    t.string "address", null: false
    t.string "network"
    t.string "payin_amount", null: false
    t.string "payin_currency"
    t.string "payout_amount"
    t.string "payout_currency"
    t.string "rate"
    t.string "invoice_url"
    t.datetime "invoice_expires_at"
    t.string "verification_url"
    t.datetime "verification_expires_at"
    t.string "error_code"
    t.bigint "telegram_user_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_orders_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["status"], name: "index_orders_on_status"
  end
end
