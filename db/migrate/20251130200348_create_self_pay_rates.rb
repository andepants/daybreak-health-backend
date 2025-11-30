class CreateSelfPayRates < ActiveRecord::Migration[7.2]
  def change
    create_table :self_pay_rates, id: :uuid do |t|
      t.string :session_type, null: false
      t.decimal :base_rate, precision: 8, scale: 2, null: false
      t.date :effective_date, null: false
      t.date :end_date
      t.boolean :sliding_scale_available, default: false, null: false
      t.boolean :package_pricing_available, default: false, null: false
      t.text :description
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :self_pay_rates, :session_type
    add_index :self_pay_rates, :effective_date
    add_index :self_pay_rates, [:session_type, :effective_date]
  end
end
