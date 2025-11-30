class AddCostEstimateToOnboardingSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :onboarding_sessions, :cost_estimate, :jsonb, default: {}
    add_index :onboarding_sessions, :cost_estimate, using: :gin
  end
end
