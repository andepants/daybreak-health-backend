class CreateTherapistMatches < ActiveRecord::Migration[7.2]
  def change
    create_table :therapist_matches, id: :uuid do |t|
      t.references :onboarding_session, null: false, foreign_key: true, type: :uuid
      t.jsonb :matched_therapists, null: false, default: []
      t.jsonb :criteria_used, null: false, default: {}
      t.integer :processing_time_ms, null: false
      t.uuid :selected_therapist_id

      t.timestamps
    end

    # Note: index already created by t.references above
    add_index :therapist_matches, :selected_therapist_id
    add_index :therapist_matches, :created_at
  end
end
