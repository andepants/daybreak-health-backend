class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments, id: :uuid do |t|
      # Foreign Keys
      t.references :therapist, type: :uuid, null: false, foreign_key: true
      t.references :onboarding_session, type: :uuid, null: false, foreign_key: true

      # Appointment Details
      t.datetime :scheduled_at, null: false, comment: "Date and time of appointment"
      t.integer :duration_minutes, null: false, default: 50, comment: "Duration in minutes"

      # Status Management
      t.integer :status, null: false, default: 0, comment: "0=scheduled, 1=confirmed, 2=cancelled, 3=completed, 4=no_show"
      t.datetime :confirmed_at, comment: "When appointment was confirmed"
      t.datetime :cancelled_at, comment: "When appointment was cancelled"
      t.string :cancellation_reason, comment: "Reason for cancellation"

      # Metadata
      t.string :location_type, default: 'virtual', comment: "virtual or in_person"
      t.string :virtual_link, comment: "Video call link for virtual appointments"
      t.text :notes, comment: "Internal notes about appointment"

      t.timestamps
    end

    # Indexes
    add_index :appointments, :scheduled_at
    add_index :appointments, :status
    add_index :appointments, [:therapist_id, :scheduled_at], unique: true,
              name: 'index_appointments_on_therapist_and_time'
    add_index :appointments, [:onboarding_session_id, :status]
  end
end
