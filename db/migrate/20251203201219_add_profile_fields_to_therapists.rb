# frozen_string_literal: true

# Migration to add extended profile fields to therapists table
#
# Adds:
# - profile_data: JSONB column for storing education, certifications, approach
# - gender, ethnicity, religion: String columns for demographic data
# - years_of_experience: Integer for experience tracking
#
# Part of the CSV clinician import feature
class AddProfileFieldsToTherapists < ActiveRecord::Migration[7.2]
  def change
    add_column :therapists, :profile_data, :jsonb, default: {}, null: false
    add_column :therapists, :gender, :string
    add_column :therapists, :ethnicity, :string
    add_column :therapists, :religion, :string
    add_column :therapists, :years_of_experience, :integer

    add_index :therapists, :gender
    add_index :therapists, :profile_data, using: :gin
  end
end
