# frozen_string_literal: true

class ConvertInsuranceImagesToActiveStorage < ActiveRecord::Migration[7.2]
  def up
    # Remove old text columns - data will be lost
    # These were encrypted text fields that stored base64 image data
    # Active Storage will use active_storage_attachments table instead
    remove_column :insurances, :card_image_front, :text if column_exists?(:insurances, :card_image_front)
    remove_column :insurances, :card_image_back, :text if column_exists?(:insurances, :card_image_back)
  end

  def down
    add_column :insurances, :card_image_front, :text
    add_column :insurances, :card_image_back, :text
  end
end
