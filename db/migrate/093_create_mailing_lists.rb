class CreateMailingLists < ActiveRecord::Migration
  def self.up
    create_table :mailing_lists do |t|
      t.string :name, :null => false
      t.string :address, :unique => true, :null => false
      t.string :locale, :null => false

      t.timestamps
    end
  end

  def self.down
    drop_table :mailing_lists
  end
end
