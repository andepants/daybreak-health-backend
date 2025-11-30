class CreateSessionRates < ActiveRecord::Migration[7.2]
  def change
    create_table :session_rates, id: :uuid do |t|
      # Service type: intake, individual_therapy, family_therapy, onsite_care
      t.string :service_type, null: false, index: true

      # Base rate for this service type in USD
      # precision: 10, scale: 2 ensures proper decimal handling for currency
      t.decimal :base_rate, precision: 10, scale: 2, null: false

      # Effective date range for this rate
      # Allows for rate versioning over time
      t.date :effective_date, null: false
      t.date :end_date

      # Optional metadata for rate description
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Index for efficient rate lookups by service type and date range
    add_index :session_rates, [:service_type, :effective_date, :end_date],
              name: 'index_session_rates_on_service_and_dates'

    # Ensure no overlapping rates for the same service type
    # Note: This would require a database constraint or application-level validation
  end
end
