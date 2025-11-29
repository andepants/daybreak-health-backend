class AddIndexToAuditLogsAction < ActiveRecord::Migration[7.2]
  def change
    add_index :audit_logs, :action
  end
end
