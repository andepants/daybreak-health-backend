# frozen_string_literal: true

class CreateParents < ActiveRecord::Migration[7.2]
  def change
    create_table :parents, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: { unique: true }

      # Encrypted PHI fields (Rails 7 encryption)
      t.text :email
      t.text :phone
      t.text :first_name
      t.text :last_name
      t.string :relationship
      t.boolean :is_guardian

      t.timestamps
    end
  end
end
