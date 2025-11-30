class AddConcernsAndMedicalHistoryToChildren < ActiveRecord::Migration[7.2]
  def change
    add_column :children, :primary_concerns, :text
    add_column :children, :medical_history, :text
  end
end
