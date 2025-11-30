class CreateTherapistTimeOffs < ActiveRecord::Migration[7.2]
  def change
    create_table :therapist_time_offs, id: :uuid do |t|
      t.references :therapist, type: :uuid, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :reason

      t.timestamps
    end

    add_index :therapist_time_offs, [:therapist_id, :start_date, :end_date]
  end
end
