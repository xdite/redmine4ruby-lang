class MailingList < ActiveRecord::Base
  validates_presence_of :name, :address, :locale, :archive_url
  validates_uniqueness_of :name, :address
  has_many :mailing_list_trackings
  has_many :projects, :through => :mailing_list_trackings
end
