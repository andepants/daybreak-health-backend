class AddConfigurationFieldsToTherapists < ActiveRecord::Migration[7.2]
  def change
    add_column :therapists, :appointment_duration_minutes, :integer, default: 50, null: false
    add_column :therapists, :buffer_time_minutes, :integer, default: 10, null: false
  end
end
