class AddArchiveUrlToMailingList < ActiveRecord::Migration
  def self.up
    add_column :mailing_lists, :archive_url, :string
  end

  def self.down
    remove_column :mailing_lists, :archive_url
  end
end
