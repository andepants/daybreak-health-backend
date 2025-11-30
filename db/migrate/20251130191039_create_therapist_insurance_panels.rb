# frozen_string_literal: true

class CreateTherapistInsurancePanels < ActiveRecord::Migration[7.2]
  def change
    create_table :therapist_insurance_panels, id: :uuid do |t|
      t.references :therapist, null: false, foreign_key: true, type: :uuid
      t.string :insurance_name, null: false, comment: 'From credentialed_insurances.csv'
      t.string :insurance_state, comment: 'State for this insurance panel'
      t.string :line_of_business, comment: 'Commercial, Medicaid, etc.'
      t.integer :network_status, default: 0, null: false, comment: '0=in_network, 1=out_of_network'
      t.string :external_insurance_id, comment: 'Reference to credentialed_insurances'

      t.timestamps
    end

    add_index :therapist_insurance_panels, [:therapist_id, :insurance_name, :insurance_state],
              unique: true, name: 'index_therapist_insurance_on_therapist_insurance_state'
    add_index :therapist_insurance_panels, :insurance_name
    add_index :therapist_insurance_panels, :network_status
  end
end
