class AddSubscriberDobToInsurances < ActiveRecord::Migration[7.2]
  def change
    add_column :insurances, :subscriber_dob, :text
    add_index :insurances, :verification_status
  end
end
