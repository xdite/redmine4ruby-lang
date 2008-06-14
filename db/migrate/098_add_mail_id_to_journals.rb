class AddMailIdToJournals < ActiveRecord::Migration
  def self.up
    add_column :journals, :mail_id, :string, :null => true
  end

  def self.down
    remove_column :journals, :mail_id
  end
end
