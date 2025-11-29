# frozen_string_literal: true

class CreateChildren < ActiveRecord::Migration[7.2]
  def change
    create_table :children, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: { unique: true }

      # Encrypted PHI fields
      t.text :first_name
      t.text :last_name
      t.text :date_of_birth  # Encrypted as text
      t.string :gender
      t.string :school_name
      t.string :grade

      t.timestamps
    end
  end
end
