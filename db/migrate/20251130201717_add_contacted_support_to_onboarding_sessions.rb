class AddContactedSupportToOnboardingSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :onboarding_sessions, :contacted_support, :boolean, default: false, null: false
  end
end
