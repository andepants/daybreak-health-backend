# frozen_string_literal: true

class CreateInsurances < ActiveRecord::Migration[7.2]
  def change
    create_table :insurances, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: { unique: true }

      t.string :payer_name
      # Encrypted PHI fields
      t.text :subscriber_name
      t.text :policy_number
      t.text :group_number

      t.integer :verification_status, default: 0
      t.jsonb :verification_result

      t.timestamps
    end
  end
end
