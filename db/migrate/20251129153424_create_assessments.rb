# frozen_string_literal: true

class CreateAssessments < ActiveRecord::Migration[7.2]
  def change
    create_table :assessments, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: { unique: true }

      t.jsonb :responses, default: {}
      t.string :risk_flags, array: true, default: []
      t.text :summary
      t.boolean :consent_given, default: false
      t.integer :score

      t.timestamps
    end
  end
end
