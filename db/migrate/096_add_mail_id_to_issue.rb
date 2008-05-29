class AddMailIdToIssue < ActiveRecord::Migration
  def self.up
    add_column :issues, :mail_id, :string
    add_index :issues, :mail_id
  end

  def self.down
    remove_index :issues, :mail_id
    remove_column :issues, :mail_id
  end
end
