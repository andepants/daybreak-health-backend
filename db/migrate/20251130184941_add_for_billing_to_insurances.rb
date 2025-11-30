class AddForBillingToInsurances < ActiveRecord::Migration[7.2]
  def change
    add_column :insurances, :for_billing, :boolean, default: true, null: false
    add_index :insurances, :for_billing

    # Set existing self_pay records to for_billing: false
    reversible do |dir|
      dir.up do
        # Use enum value for self_pay (8)
        execute <<-SQL
          UPDATE insurances
          SET for_billing = false
          WHERE verification_status = 8
        SQL
      end
    end
  end
end
