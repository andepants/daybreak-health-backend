class AddRoleToOnboardingSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :onboarding_sessions, :role, :integer, default: 0, null: false
    add_index :onboarding_sessions, :role
  end
end
