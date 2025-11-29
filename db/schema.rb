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

ActiveRecord::Schema[7.2].define(version: 2025_11_29_192929) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "assessments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.jsonb "responses", default: {}
    t.string "risk_flags", default: [], array: true
    t.text "summary"
    t.boolean "consent_given", default: false
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_assessments_on_onboarding_session_id", unique: true
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id"
    t.uuid "user_id"
    t.string "action", null: false
    t.string "resource", null: false
    t.uuid "resource_id"
    t.jsonb "details"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["onboarding_session_id"], name: "index_audit_logs_on_onboarding_session_id"
    t.index ["resource", "resource_id"], name: "index_audit_logs_on_resource_and_resource_id"
  end

  create_table "children", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.text "first_name"
    t.text "last_name"
    t.text "date_of_birth"
    t.string "gender"
    t.string "school_name"
    t.string "grade"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_children_on_onboarding_session_id", unique: true
  end

  create_table "insurances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.string "payer_name"
    t.text "subscriber_name"
    t.text "policy_number"
    t.text "group_number"
    t.integer "verification_status", default: 0
    t.jsonb "verification_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "member_id"
    t.text "card_image_front"
    t.text "card_image_back"
    t.index ["onboarding_session_id"], name: "index_insurances_on_onboarding_session_id", unique: true
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.integer "role", null: false
    t.text "content"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id", "created_at"], name: "index_messages_on_onboarding_session_id_and_created_at"
    t.index ["onboarding_session_id"], name: "index_messages_on_onboarding_session_id"
  end

  create_table "onboarding_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.jsonb "progress", default: {}
    t.datetime "expires_at", null: false
    t.string "referral_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.index ["created_at"], name: "index_onboarding_sessions_on_created_at"
    t.index ["role"], name: "index_onboarding_sessions_on_role"
    t.index ["status"], name: "index_onboarding_sessions_on_status"
  end

  create_table "parents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.text "email"
    t.text "phone"
    t.text "first_name"
    t.text "last_name"
    t.string "relationship"
    t.boolean "is_guardian"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_parents_on_onboarding_session_id", unique: true
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.text "token_hash", null: false
    t.string "device_fingerprint"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["onboarding_session_id"], name: "index_refresh_tokens_on_onboarding_session_id"
    t.index ["revoked_at"], name: "index_refresh_tokens_on_revoked_at"
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
  end

  add_foreign_key "assessments", "onboarding_sessions"
  add_foreign_key "audit_logs", "onboarding_sessions"
  add_foreign_key "children", "onboarding_sessions"
  add_foreign_key "insurances", "onboarding_sessions"
  add_foreign_key "messages", "onboarding_sessions"
  add_foreign_key "parents", "onboarding_sessions"
  add_foreign_key "refresh_tokens", "onboarding_sessions"
end
