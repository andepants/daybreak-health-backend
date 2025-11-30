class CreateSupportRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :support_requests, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: true
      t.string :intercom_conversation_id
      t.string :source, null: false
      t.boolean :resolved, default: false, null: false
      t.timestamps
    end

    add_index :support_requests, :created_at
    add_index :support_requests, :intercom_conversation_id
  end
end
