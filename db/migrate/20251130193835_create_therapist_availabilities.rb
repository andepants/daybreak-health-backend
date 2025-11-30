class CreateTherapistAvailabilities < ActiveRecord::Migration[7.2]
  def change
    create_table :therapist_availabilities, id: :uuid do |t|
      t.references :therapist, null: false, foreign_key: true, type: :uuid
      t.integer :day_of_week, null: false, comment: '0 = Sunday, 1 = Monday, ... 6 = Saturday'
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :timezone, null: false, comment: 'IANA timezone (e.g., America/Los_Angeles)'
      t.boolean :is_repeating, default: true, null: false

      t.timestamps
    end

    add_index :therapist_availabilities, [:therapist_id, :day_of_week]
    add_index :therapist_availabilities, :timezone

    # Add check constraint for valid day_of_week
    execute <<-SQL
      ALTER TABLE therapist_availabilities
        ADD CONSTRAINT check_day_of_week
        CHECK (day_of_week >= 0 AND day_of_week <= 6)
    SQL
  end
end
