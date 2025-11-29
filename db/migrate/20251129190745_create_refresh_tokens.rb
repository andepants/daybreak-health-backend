class CreateRefreshTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :refresh_tokens, id: :uuid do |t|
      t.references :onboarding_session, type: :uuid, foreign_key: true, null: false, index: true
      t.text :token_hash, null: false
      t.string :device_fingerprint
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :refresh_tokens, :token_hash, unique: true
    add_index :refresh_tokens, :expires_at
    add_index :refresh_tokens, :revoked_at
  end
end
