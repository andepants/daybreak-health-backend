# frozen_string_literal: true

module Types
  # GraphQL type for TherapistInsurancePanel model
  #
  # Represents insurance panels that a therapist is credentialed with.
  class InsurancePanelType < Types::BaseObject
    description 'Insurance panel information for a therapist'

    field :id, ID, null: false, description: 'Unique identifier'
    field :insurance_name, String, null: false, description: 'Insurance payer name'
    field :insurance_state, String, null: true, description: 'State for this insurance panel'
    field :line_of_business, String, null: true, description: 'Line of business (Commercial, Medicaid, etc.)'
    field :network_status, String, null: false, description: 'Network status (in_network or out_of_network)'
  end
end
