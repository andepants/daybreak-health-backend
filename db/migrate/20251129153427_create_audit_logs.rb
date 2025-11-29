# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, index: true
      t.uuid :user_id

      t.string :action, null: false
      t.string :resource, null: false
      t.uuid :resource_id
      t.jsonb :details
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :created_at
    add_index :audit_logs, %i[resource resource_id]
  end
end
