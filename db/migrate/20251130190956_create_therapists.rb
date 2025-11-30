# frozen_string_literal: true

class CreateTherapists < ActiveRecord::Migration[7.2]
  def change
    create_table :therapists, id: :uuid do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.string :license_type, comment: 'LCSW, LMFT, LPCC, etc.'
      t.string :license_number
      t.string :license_state
      t.date :license_expiration
      t.string :npi_number, comment: 'National Provider Identifier'
      t.text :bio
      t.string :photo_url
      t.boolean :active, default: true, null: false
      t.string :languages, array: true, default: [], comment: 'Array of ISO 639-1 language codes'
      t.string :age_ranges, array: true, default: [], comment: "e.g., ['5-12', '13-17']"
      t.string :treatment_modalities, array: true, default: [], comment: 'CBT, DBT, EMDR, etc.'
      t.string :external_id, comment: 'Reference to external system (Healthie)'

      t.timestamps
    end

    add_index :therapists, :active
    add_index :therapists, :license_state
    add_index :therapists, :external_id, unique: true
    add_index :therapists, :license_number, unique: true
    add_index :therapists, :npi_number, unique: true
  end
end
