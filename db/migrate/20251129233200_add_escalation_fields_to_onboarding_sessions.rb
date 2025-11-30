class AddEscalationFieldsToOnboardingSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :onboarding_sessions, :needs_human_contact, :boolean, default: false, null: false
    add_column :onboarding_sessions, :escalation_requested_at, :datetime
    add_column :onboarding_sessions, :escalation_reason, :text

    add_index :onboarding_sessions, :needs_human_contact
    add_index :onboarding_sessions, :escalation_requested_at
  end
end
