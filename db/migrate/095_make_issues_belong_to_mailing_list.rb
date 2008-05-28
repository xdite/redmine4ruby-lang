class MakeIssuesBelongToMailingList < ActiveRecord::Migration
  def self.up
    add_column :issues, :mailing_list_id, :integer
    add_column :issues, :mailing_list_code, :string, :null => true

    Issue.find(:all).each do |issue|
      issue.mailing_list = issue.project.mailing_lists.first
      issue.save!
    end
    change_column_null :isues, :mailing_list_id rescue nil
    add_index :issues, [:mailing_list_id, :mailing_list_code], :name => 'mail_identifier'
  end

  def self.down
    remove_index :issues, :name => 'mail_identifier'
    remove_column :issues, :mailing_list_id
    remove_column :issues, :mailing_list_code
  end

  class Issue < ActiveRecord::Base
    belongs_to :project
    belongs_to :mailing_list
  end
  class Project < ActiveRecord::Base
    has_many :issues
    has_many :mailing_list_trackings
    has_many :mailing_lists, :through => :mailing_list_trackings
  end
  class MailingList < ActiveRecord::Base
    has_many :mailing_list_trackings
    has_many :projects, :through => :mailing_list_trackings
  end
  class MailingListTracking < ActiveRecord::Base
    belongs_to :mailing_list
    belongs_to :project
  end
end
