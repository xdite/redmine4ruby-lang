# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.dirname(__FILE__) + '/../test_helper'

class MailerTest < Test::Unit::TestCase
  fixtures :projects, :issues, :users, :members, :documents, :attachments, :news, :tokens, :journals, :journal_details, :changesets, :trackers, :issue_statuses, :enumerations
  fixtures :messages, :boards
  fixtures :mailing_lists, :mailing_list_trackings
  
  def test_generated_links_in_emails
    ActionMailer::Base.deliveries.clear
    Setting.host_name = 'mydomain.foo'
    Setting.protocol = 'https'
    
    journal = Journal.find(2)
    assert Mailer.deliver_issue_edit(journal)
    
    mail = ActionMailer::Base.deliveries.last
    assert_kind_of TMail::Mail, mail
    # link to the main ticket
    assert mail.subject.include?("Bug #1")
    assert mail.subject.include?("Can't print recipes")
    assert mail.body.include?("https://mydomain.foo/issues/show/1")
    
=begin
    # link to a referenced ticket
    assert mail.body.include?('<a href="https://mydomain.foo/issues/show/2" class="issue" title="Add ingredients categories (Assigned)">#2</a>')
    # link to a changeset
    assert mail.body.include?('<a href="https://mydomain.foo/repositories/revision/ecookbook?rev=2" class="changeset" title="This commit fixes #1, #2 and references #1 &amp; #3">r2</a>')
=end
  end
  
  # test mailer methods for each language
  def test_issue_add
    issue = Issue.find(1)
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      issue.mailing_list.locale = lang.to_s

      assert Mailer.deliver_issue_add(issue)

      mail = ActionMailer::Base.deliveries.last
      assert_kind_of TMail::Mail, mail
      assert_equal 'redmine@somenet.foo', mail.from.first
      assert mail.header['from'].body.include?(issue.author.to_s)
      assert_equal 'text/plain', mail.content_type
      assert_equal "1", mail.header['x-redmine-issue-id'].body

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
  def test_issue_add_by_anonymous
    issue = Issue.find(1)
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      issue.mailing_list.locale = lang.to_s
      issue.author = User.anonymous

      assert Mailer.deliver_issue_add(issue)

      mail = ActionMailer::Base.deliveries.last
      assert_kind_of TMail::Mail, mail
      assert_equal 'redmine@somenet.foo', mail.from.first
      assert mail.header['from'].body.include?('Anonymous')
      assert_equal 'text/plain', mail.content_type
      assert_equal "1", mail.header['x-redmine-issue-id'].body

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end

  def test_issue_edit
    journal = Journal.find(1)
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      journal.journalized.mailing_list.locale = lang.to_s

      assert Mailer.deliver_issue_edit(journal)

      mail = ActionMailer::Base.deliveries.last
      assert_kind_of TMail::Mail, mail
      assert_equal 'redmine@somenet.foo', mail.from.first
      assert mail.header['from'].body.include?(journal.user.to_s)
      assert !mail.header['from'].body.include?(journal.issue.author.to_s)
      assert !mail.body.include?(journal.issue.description)
      assert_equal "1", mail.header['x-redmine-issue-id'].body
      assert_equal "1", mail.header['x-redmine-journal-id'].body
      assert_equal 'text/plain', mail.content_type
      assert mail.header['references'].body.include?("<123456789ABCDEF@redmine.example.com>")

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
  
  def test_document_added
    document = Document.find(1)
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.deliver_document_added(document)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
  
  def test_attachments_added
    attachements = [ Attachment.find_by_container_type('Document') ]
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.deliver_attachments_added(attachements)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type
      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
  
  def test_news_added
    news = News.find(:first)
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.deliver_news_added(news)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type
      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
  
  def test_message_posted
    message = Message.find(:first)
    recipients = ([message.root] + message.root.children).collect {|m| m.author.mail if m.author}
    recipients = recipients.compact.uniq
    GLoc.valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.deliver_message_posted(message, recipients)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type
    end
  end
  
  def test_account_information
    user = User.find(:first)
    GLoc.valid_languages.each do |lang|
      user.update_attribute :language, lang.to_s
      user.reload
      assert Mailer.deliver_account_information(user, 'pAsswORd')

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type
      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end

  def test_lost_password
    token = Token.find(2)
    GLoc.valid_languages.each do |lang|
      token.user.update_attribute :language, lang.to_s
      token.reload
      assert Mailer.deliver_lost_password(token)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end

  def test_register
    token = Token.find(1)
    GLoc.valid_languages.each do |lang|
      token.user.update_attribute :language, lang.to_s
      token.reload
      assert Mailer.deliver_register(token)

      mail = ActionMailer::Base.deliveries.last
      assert_equal 'text/plain', mail.content_type

      assert (lang==:ja ? 'iso-2022-jp' : 'utf-8'), mail.charset 
    end
  end
end
