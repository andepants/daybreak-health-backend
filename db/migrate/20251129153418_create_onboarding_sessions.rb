# frozen_string_literal: true

class CreateOnboardingSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :onboarding_sessions, id: :uuid do |t|
      t.integer :status, default: 0, null: false
      t.jsonb :progress, default: {}
      t.datetime :expires_at, null: false
      t.string :referral_source

      t.timestamps
    end

    add_index :onboarding_sessions, :status
    add_index :onboarding_sessions, :created_at
  end
end
