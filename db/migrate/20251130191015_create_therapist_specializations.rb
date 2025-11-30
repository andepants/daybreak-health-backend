# frozen_string_literal: true

class CreateTherapistSpecializations < ActiveRecord::Migration[7.2]
  def change
    create_table :therapist_specializations, id: :uuid do |t|
      t.references :therapist, null: false, foreign_key: true, type: :uuid
      t.string :specialization, null: false, comment: 'anxiety, depression, ADHD, trauma, etc.'

      t.timestamps
    end

    add_index :therapist_specializations, [:therapist_id, :specialization], unique: true, name: 'index_therapist_spec_on_therapist_and_specialization'
    add_index :therapist_specializations, :specialization
  end
end
