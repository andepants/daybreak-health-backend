class ChangeParentRelationshipToInteger < ActiveRecord::Migration[7.2]
  def up
    # Convert string relationship values to integer enum values
    # Default any existing values to 'other' (4)
    change_column :parents, :relationship, :integer, using: '4', default: 4
  end

  def down
    change_column :parents, :relationship, :string
  end
end
