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

ActiveRecord::Schema[7.2].define(version: 2025_12_03_201219) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.string "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "therapist_id", null: false
    t.uuid "onboarding_session_id", null: false
    t.datetime "scheduled_at", null: false, comment: "Date and time of appointment"
    t.integer "duration_minutes", default: 50, null: false, comment: "Duration in minutes"
    t.integer "status", default: 0, null: false, comment: "0=scheduled, 1=confirmed, 2=cancelled, 3=completed, 4=no_show"
    t.datetime "confirmed_at", comment: "When appointment was confirmed"
    t.datetime "cancelled_at", comment: "When appointment was cancelled"
    t.string "cancellation_reason", comment: "Reason for cancellation"
    t.string "location_type", default: "virtual", comment: "virtual or in_person"
    t.string "virtual_link", comment: "Video call link for virtual appointments"
    t.text "notes", comment: "Internal notes about appointment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id", "status"], name: "index_appointments_on_onboarding_session_id_and_status"
    t.index ["onboarding_session_id"], name: "index_appointments_on_onboarding_session_id"
    t.index ["scheduled_at"], name: "index_appointments_on_scheduled_at"
    t.index ["status"], name: "index_appointments_on_status"
    t.index ["therapist_id", "scheduled_at"], name: "index_appointments_on_therapist_and_time", unique: true
    t.index ["therapist_id"], name: "index_appointments_on_therapist_id"
  end

  create_table "assessments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.jsonb "responses", default: {}
    t.string "risk_flags", default: [], array: true
    t.text "summary"
    t.boolean "consent_given", default: false
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.string "assessment_mode", default: "conversational"
    t.index ["onboarding_session_id"], name: "index_assessments_on_onboarding_session_id", unique: true
    t.index ["status"], name: "index_assessments_on_status"
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
    t.text "primary_concerns"
    t.text "medical_history"
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
    t.text "subscriber_dob"
    t.integer "retry_attempts", default: 0, null: false
    t.boolean "for_billing", default: true, null: false
    t.index ["for_billing"], name: "index_insurances_on_for_billing"
    t.index ["onboarding_session_id"], name: "index_insurances_on_onboarding_session_id", unique: true
    t.index ["verification_status"], name: "index_insurances_on_verification_status"
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
    t.boolean "needs_human_contact", default: false, null: false
    t.datetime "escalation_requested_at"
    t.text "escalation_reason"
    t.jsonb "cost_estimate", default: {}
    t.boolean "contacted_support"
    t.index ["cost_estimate"], name: "index_onboarding_sessions_on_cost_estimate", using: :gin
    t.index ["created_at"], name: "index_onboarding_sessions_on_created_at"
    t.index ["escalation_requested_at"], name: "index_onboarding_sessions_on_escalation_requested_at"
    t.index ["needs_human_contact"], name: "index_onboarding_sessions_on_needs_human_contact"
    t.index ["role"], name: "index_onboarding_sessions_on_role"
    t.index ["status"], name: "index_onboarding_sessions_on_status"
  end

  create_table "parents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.text "email"
    t.text "phone"
    t.text "first_name"
    t.text "last_name"
    t.integer "relationship", default: 4
    t.boolean "is_guardian"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_parents_on_onboarding_session_id", unique: true
  end

  create_table "patient_availabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.integer "duration_minutes", default: 60, null: false
    t.string "timezone", default: "America/Los_Angeles", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id", "day_of_week"], name: "idx_patient_avail_session_day"
    t.index ["onboarding_session_id"], name: "index_patient_availabilities_on_onboarding_session_id"
  end

  create_table "payment_plans", force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.integer "plan_duration_months", null: false, comment: "Payment plan duration in months (0 for upfront)"
    t.decimal "monthly_amount", precision: 10, scale: 2, null: false, comment: "Monthly payment amount in USD"
    t.decimal "total_amount", precision: 10, scale: 2, null: false, comment: "Total cost including fees/interest in USD"
    t.decimal "discount_applied", precision: 10, scale: 2, default: "0.0", comment: "Discount amount applied in USD"
    t.integer "payment_method_preference", default: 0, null: false, comment: "Enum: 0=card, 1=hsa_fsa, 2=bank_transfer"
    t.integer "status", default: 0, null: false, comment: "Enum: 0=pending, 1=active, 2=completed, 3=cancelled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id", "status"], name: "index_payment_plans_on_onboarding_session_id_and_status"
    t.index ["onboarding_session_id"], name: "index_payment_plans_on_onboarding_session_id"
    t.index ["status"], name: "index_payment_plans_on_status"
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

  create_table "self_pay_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "session_type", null: false
    t.decimal "base_rate", precision: 8, scale: 2, null: false
    t.date "effective_date", null: false
    t.date "end_date"
    t.boolean "sliding_scale_available", default: false, null: false
    t.boolean "package_pricing_available", default: false, null: false
    t.text "description"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effective_date"], name: "index_self_pay_rates_on_effective_date"
    t.index ["session_type", "effective_date"], name: "index_self_pay_rates_on_session_type_and_effective_date"
    t.index ["session_type"], name: "index_self_pay_rates_on_session_type"
  end

  create_table "session_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "service_type", null: false
    t.decimal "base_rate", precision: 10, scale: 2, null: false
    t.date "effective_date", null: false
    t.date "end_date"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_type", "effective_date", "end_date"], name: "index_session_rates_on_service_and_dates"
    t.index ["service_type", "effective_date"], name: "index_session_rates_unique_service_effective", unique: true, where: "(end_date IS NULL)"
    t.index ["service_type"], name: "index_session_rates_on_service_type"
  end

  create_table "support_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.string "intercom_conversation_id"
    t.string "source", null: false
    t.boolean "resolved", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_support_requests_on_created_at"
    t.index ["intercom_conversation_id"], name: "index_support_requests_on_intercom_conversation_id"
    t.index ["onboarding_session_id"], name: "index_support_requests_on_onboarding_session_id"
  end

  create_table "therapist_availabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "therapist_id", null: false
    t.integer "day_of_week", null: false, comment: "0 = Sunday, 1 = Monday, ... 6 = Saturday"
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.string "timezone", null: false, comment: "IANA timezone (e.g., America/Los_Angeles)"
    t.boolean "is_repeating", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["therapist_id", "day_of_week"], name: "index_therapist_availabilities_on_therapist_id_and_day_of_week"
    t.index ["therapist_id"], name: "index_therapist_availabilities_on_therapist_id"
    t.index ["timezone"], name: "index_therapist_availabilities_on_timezone"
    t.check_constraint "day_of_week >= 0 AND day_of_week <= 6", name: "check_day_of_week"
  end

  create_table "therapist_insurance_panels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "therapist_id", null: false
    t.string "insurance_name", null: false, comment: "From credentialed_insurances.csv"
    t.string "insurance_state", comment: "State for this insurance panel"
    t.string "line_of_business", comment: "Commercial, Medicaid, etc."
    t.integer "network_status", default: 0, null: false, comment: "0=in_network, 1=out_of_network"
    t.string "external_insurance_id", comment: "Reference to credentialed_insurances"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["insurance_name"], name: "index_therapist_insurance_panels_on_insurance_name"
    t.index ["network_status"], name: "index_therapist_insurance_panels_on_network_status"
    t.index ["therapist_id", "insurance_name", "insurance_state"], name: "index_therapist_insurance_on_therapist_insurance_state", unique: true
    t.index ["therapist_id"], name: "index_therapist_insurance_panels_on_therapist_id"
  end

  create_table "therapist_matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "onboarding_session_id", null: false
    t.jsonb "matched_therapists", default: [], null: false
    t.jsonb "criteria_used", default: {}, null: false
    t.integer "processing_time_ms", null: false
    t.uuid "selected_therapist_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_therapist_matches_on_onboarding_session_id"
  end

  create_table "therapist_specializations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "therapist_id", null: false
    t.string "specialization", null: false, comment: "anxiety, depression, ADHD, trauma, etc."
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["specialization"], name: "index_therapist_specializations_on_specialization"
    t.index ["therapist_id", "specialization"], name: "index_therapist_spec_on_therapist_and_specialization", unique: true
    t.index ["therapist_id"], name: "index_therapist_specializations_on_therapist_id"
  end

  create_table "therapist_time_offs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "therapist_id", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["therapist_id", "start_date", "end_date"], name: "idx_on_therapist_id_start_date_end_date_69a99e077b"
    t.index ["therapist_id"], name: "index_therapist_time_offs_on_therapist_id"
  end

  create_table "therapists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email"
    t.string "phone"
    t.string "license_type", comment: "LCSW, LMFT, LPCC, etc."
    t.string "license_number"
    t.string "license_state"
    t.date "license_expiration"
    t.string "npi_number", comment: "National Provider Identifier"
    t.text "bio"
    t.string "photo_url"
    t.boolean "active", default: true, null: false
    t.string "languages", default: [], comment: "Array of ISO 639-1 language codes", array: true
    t.string "age_ranges", default: [], comment: "e.g., ['5-12', '13-17']", array: true
    t.string "treatment_modalities", default: [], comment: "CBT, DBT, EMDR, etc.", array: true
    t.string "external_id", comment: "Reference to external system (Healthie)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "appointment_duration_minutes", default: 50, null: false
    t.integer "buffer_time_minutes", default: 10, null: false
    t.jsonb "profile_data", default: {}, null: false
    t.string "gender"
    t.string "ethnicity"
    t.string "religion"
    t.integer "years_of_experience"
    t.index ["active"], name: "index_therapists_on_active"
    t.index ["external_id"], name: "index_therapists_on_external_id", unique: true
    t.index ["gender"], name: "index_therapists_on_gender"
    t.index ["license_number"], name: "index_therapists_on_license_number", unique: true
    t.index ["license_state"], name: "index_therapists_on_license_state"
    t.index ["npi_number"], name: "index_therapists_on_npi_number", unique: true
    t.index ["profile_data"], name: "index_therapists_on_profile_data", using: :gin
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "onboarding_sessions"
  add_foreign_key "appointments", "therapists"
  add_foreign_key "assessments", "onboarding_sessions"
  add_foreign_key "audit_logs", "onboarding_sessions"
  add_foreign_key "children", "onboarding_sessions"
  add_foreign_key "insurances", "onboarding_sessions"
  add_foreign_key "messages", "onboarding_sessions"
  add_foreign_key "parents", "onboarding_sessions"
  add_foreign_key "patient_availabilities", "onboarding_sessions"
  add_foreign_key "payment_plans", "onboarding_sessions"
  add_foreign_key "refresh_tokens", "onboarding_sessions"
  add_foreign_key "support_requests", "onboarding_sessions"
  add_foreign_key "therapist_availabilities", "therapists"
  add_foreign_key "therapist_insurance_panels", "therapists"
  add_foreign_key "therapist_matches", "onboarding_sessions"
  add_foreign_key "therapist_specializations", "therapists"
  add_foreign_key "therapist_time_offs", "therapists"
end
