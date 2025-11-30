# frozen_string_literal: true

class AddUniqueConstraintToSessionRates < ActiveRecord::Migration[7.2]
  def change
    # Add unique constraint to prevent overlapping rates for the same service type
    # This ensures data integrity by preventing duplicate active rates for the same service
    # The constraint covers service_type and effective_date, allowing for rate versioning
    add_index :session_rates, [:service_type, :effective_date],
              unique: true,
              name: 'index_session_rates_unique_service_effective',
              where: 'end_date IS NULL'
  end
end
