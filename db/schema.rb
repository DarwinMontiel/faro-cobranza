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

ActiveRecord::Schema[8.1].define(version: 2026_11_12_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "full_name", null: false
    t.string "email"
    t.string "phone"
    t.string "city", null: false
    t.string "segment", default: "masivo", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_clients_on_document_number", unique: true
    t.index ["full_name"], name: "index_clients_on_full_name", opclass: :gin_trgm_ops, using: :gin
    t.check_constraint "document_number::text ~ '^[0-9]{6,10}$'::text", name: "clients_document_number_format"
    t.check_constraint "segment::text = ANY (ARRAY['masivo'::character varying, 'preferente'::character varying, 'pyme'::character varying]::text[])", name: "clients_segment_check"
  end

  create_table "collection_activities", force: :cascade do |t|
    t.bigint "obligation_id", null: false
    t.bigint "user_id", null: false
    t.string "channel", null: false
    t.string "outcome", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.date "promise_date"
    t.decimal "promise_amount", precision: 15, scale: 2
    t.string "source", default: "web", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["obligation_id", "occurred_at"], name: "index_collection_activities_on_obligation_id_and_occurred_at"
    t.index ["obligation_id"], name: "index_collection_activities_on_obligation_id"
    t.index ["occurred_at"], name: "index_collection_activities_on_occurred_at"
    t.index ["user_id"], name: "index_collection_activities_on_user_id"
    t.check_constraint "channel::text = ANY (ARRAY['call'::character varying, 'whatsapp'::character varying, 'visit'::character varying, 'email'::character varying, 'sms'::character varying]::text[])", name: "activities_channel_check"
    t.check_constraint "outcome::text <> 'promise_to_pay'::text OR promise_date IS NOT NULL AND promise_amount IS NOT NULL AND promise_amount > 0::numeric", name: "activities_promise_complete"
    t.check_constraint "outcome::text = ANY (ARRAY['no_answer'::character varying, 'voicemail'::character varying, 'wrong_number'::character varying, 'contact_holder'::character varying, 'contact_third_party'::character varying, 'refused'::character varying, 'promise_to_pay'::character varying]::text[])", name: "activities_outcome_check"
    t.check_constraint "source::text = ANY (ARRAY['web'::character varying, 'api'::character varying]::text[])", name: "activities_source_check"
  end

  create_table "installments", force: :cascade do |t|
    t.bigint "payment_agreement_id", null: false
    t.integer "number", null: false
    t.date "due_on", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_on"], name: "index_installments_on_due_on"
    t.index ["payment_agreement_id", "number"], name: "index_installments_on_payment_agreement_id_and_number", unique: true
    t.index ["payment_agreement_id"], name: "index_installments_on_payment_agreement_id"
    t.check_constraint "amount > 0::numeric", name: "installments_amount_positive"
  end

  create_table "obligations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "number", null: false
    t.string "product", null: false
    t.decimal "principal_balance", precision: 15, scale: 2, null: false
    t.integer "days_past_due", default: 0, null: false
    t.string "status", default: "current", null: false
    t.date "disbursed_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "past_due_since"
    t.index ["client_id"], name: "index_obligations_on_client_id"
    t.index ["number"], name: "index_obligations_on_number", unique: true
    t.index ["past_due_since"], name: "index_obligations_on_past_due_since", where: "(past_due_since IS NOT NULL)"
    t.index ["status", "days_past_due"], name: "index_obligations_on_status_and_days_past_due"
    t.check_constraint "days_past_due >= 0", name: "obligations_days_past_due_non_negative"
    t.check_constraint "principal_balance >= 0::numeric", name: "obligations_balance_non_negative"
    t.check_constraint "product::text = ANY (ARRAY['credit_card'::character varying, 'personal_loan'::character varying, 'microcredit'::character varying, 'vehicle'::character varying]::text[])", name: "obligations_product_check"
    t.check_constraint "status::text = ANY (ARRAY['current'::character varying, 'delinquent'::character varying, 'in_agreement'::character varying, 'paid_off'::character varying, 'charged_off'::character varying]::text[])", name: "obligations_status_check"
  end

  create_table "payment_agreements", force: :cascade do |t|
    t.bigint "obligation_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "active", null: false
    t.decimal "total_amount", precision: 15, scale: 2, null: false
    t.string "reference", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["obligation_id"], name: "index_payment_agreements_on_obligation_id"
    t.index ["obligation_id"], name: "index_payment_agreements_one_active_per_obligation", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["reference"], name: "index_payment_agreements_on_reference", unique: true
    t.index ["user_id"], name: "index_payment_agreements_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'fulfilled'::character varying, 'broken'::character varying, 'cancelled'::character varying]::text[])", name: "agreements_status_check"
    t.check_constraint "total_amount > 0::numeric", name: "agreements_total_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "agent", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'agent'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "collection_activities", "obligations"
  add_foreign_key "collection_activities", "users"
  add_foreign_key "installments", "payment_agreements", on_delete: :cascade
  add_foreign_key "obligations", "clients"
  add_foreign_key "payment_agreements", "obligations"
  add_foreign_key "payment_agreements", "users"
  add_foreign_key "sessions", "users"
end
