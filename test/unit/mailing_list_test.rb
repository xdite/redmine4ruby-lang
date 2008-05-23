require File.dirname(__FILE__) + '/../test_helper'

class MailingListTest < ActiveSupport::TestCase
  fixtures :mailing_lists
  def test_new
    list = MailingList.new \
      :name => 'ruby-talk', 
      :address => 'ruby-talk@ruby-lang.org', 
      :locale => 'en'
    assert_valid list
  end
  def test_new_without_name
    list = MailingList.new \
      :name => nil,
      :address => 'ruby-talk@ruby-lang.org', 
      :locale => 'en'
    assert !list.valid?
  end
  def test_new_without_address
    list = MailingList.new \
      :name => 'ruby-talk',
      :address => nil, 
      :locale => 'en'
    assert !list.valid?
  end
  def test_new_with_existing_address
    list = MailingList.new \
      :name => 'ruby-talk',
      :address => 'ruby-dev@ruby-lang.org',
      :locale => 'en'
    assert !list.valid?
  end
  def test_new_without_locale
    list = MailingList.new \
      :name => 'ruby-talk',
      :address => 'ruby-talk@ruby-lang.org', 
      :locale => nil
    assert !list.valid?
  end
end
