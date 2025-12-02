# frozen_string_literal: true

# Fix ActiveStorage tables to work with UUID primary keys
#
# The original ActiveStorage migration created record_id as bigint,
# but our models (Insurance, etc.) use UUID primary keys.
# This migration converts the polymorphic record_id column to support UUIDs.
class FixActiveStorageForUuid < ActiveRecord::Migration[7.1]
  def up
    # First, drop the existing index that includes record_id
    remove_index :active_storage_attachments, name: :index_active_storage_attachments_uniqueness

    # Change record_id from bigint to string to support UUIDs
    # (Using string instead of uuid type for maximum compatibility)
    change_column :active_storage_attachments, :record_id, :string, null: false

    # Recreate the uniqueness index
    add_index :active_storage_attachments,
              [:record_type, :record_id, :name, :blob_id],
              name: :index_active_storage_attachments_uniqueness,
              unique: true
  end

  def down
    # This is a destructive migration - can't convert back cleanly if there's UUID data
    raise ActiveRecord::IrreversibleMigration, "Cannot convert record_id back to bigint if UUID data exists"
  end
end
