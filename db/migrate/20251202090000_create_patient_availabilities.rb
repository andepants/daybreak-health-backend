# frozen_string_literal: true

# Create patient_availabilities table to store when patients are available
# for therapy sessions. This data is used in therapist matching to filter
# and score therapists based on availability overlap.
#
# Schema:
#   - onboarding_session_id: Links to the patient's onboarding session
#   - day_of_week: 0 (Sunday) through 6 (Saturday)
#   - start_time: Start time of the availability block
#   - duration_minutes: Length of the block (default 60 minutes)
#   - timezone: IANA timezone string (e.g., "America/Los_Angeles")
#
class CreatePatientAvailabilities < ActiveRecord::Migration[7.1]
  def change
    create_table :patient_availabilities, id: :uuid do |t|
      t.uuid :onboarding_session_id, null: false
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.string :timezone, null: false, default: "America/Los_Angeles"

      t.timestamps
    end

    add_foreign_key :patient_availabilities, :onboarding_sessions
    add_index :patient_availabilities, :onboarding_session_id
    add_index :patient_availabilities, %i[onboarding_session_id day_of_week],
              name: "idx_patient_avail_session_day"
  end
end
