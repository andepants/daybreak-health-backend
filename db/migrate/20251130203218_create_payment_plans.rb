class CreatePaymentPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :payment_plans do |t|
      t.references :onboarding_session, null: false, foreign_key: true, type: :uuid
      t.integer :plan_duration_months, null: false, comment: 'Payment plan duration in months (0 for upfront)'
      t.decimal :monthly_amount, precision: 10, scale: 2, null: false, comment: 'Monthly payment amount in USD'
      t.decimal :total_amount, precision: 10, scale: 2, null: false, comment: 'Total cost including fees/interest in USD'
      t.decimal :discount_applied, precision: 10, scale: 2, default: 0.0, comment: 'Discount amount applied in USD'
      t.integer :payment_method_preference, null: false, default: 0, comment: 'Enum: 0=card, 1=hsa_fsa, 2=bank_transfer'
      t.integer :status, null: false, default: 0, comment: 'Enum: 0=pending, 1=active, 2=completed, 3=cancelled'

      t.timestamps
    end

    add_index :payment_plans, :status
    add_index :payment_plans, [:onboarding_session_id, :status]
  end
end
