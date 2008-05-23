class CreateMailingListTrackings < ActiveRecord::Migration
  def self.up
    create_table :mailing_list_trackings do |t|
      t.integer :project_id, :null => false
      t.integer :mailing_list_id, :null => false
      t.string :project_selector_pattern, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :mailing_list_trackings
  end
end
