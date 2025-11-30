# frozen_string_literal: true

class AddStatusToAssessments < ActiveRecord::Migration[7.2]
  def change
    add_column :assessments, :status, :integer, default: 0, null: false
    add_column :assessments, :assessment_mode, :string, default: 'conversational'
    add_index :assessments, :status
  end
end
