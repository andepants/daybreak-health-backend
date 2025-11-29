# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false

      t.integer :role, null: false  # parent, therapist, system
      t.text :content               # Encrypted
      t.jsonb :metadata

      t.timestamps
    end

    add_index :messages, %i[onboarding_session_id created_at]
  end
end
