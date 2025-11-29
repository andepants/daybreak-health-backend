# frozen_string_literal: true

class AddMissingFieldsToInsurance < ActiveRecord::Migration[7.2]
  def change
    add_column :insurances, :member_id, :text
    add_column :insurances, :card_image_front, :text
    add_column :insurances, :card_image_back, :text
  end
end
