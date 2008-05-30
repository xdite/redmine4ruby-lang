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

class MailHandler < ActionMailer::Base
  
  # Processes incoming emails
  def receive(email)
    tracker_tags = Tracker.find(:all).map{|tracker|
      /\[(#{Regexp.escape tracker.name}):(.*?)\]/i
    }
    return resolve_issue(email) if email.header['x-redmine-issue-id']

    case email.subject
    when %r{\[.*#(\d+)\]}   # find related issue by parsing the subject
      add_note_from(email, $1)
    when *tracker_tags
      add_issue_from(email, $1, $2)
    else
      unless attempt_to_recognize_as_reply(email)
        logger.warn("Unhandled mail received: #{email.to_s}")
      end
    end
  rescue
    logger.error($!.message + ':' + $!.backtrace.join("\n"))
  end

  private

  def add_note_from(email, issue_id)
    issue = Issue.find_by_id(issue_id)
    return unless issue
    
    # find user
    user = User.find_active(:first, :conditions => {:mail => email.from.first})
    user ||= User.anonymous
    # check permission
    return unless user.allowed_to?(:add_issue_notes, issue.project)
    
    # add the note
    issue.init_journal(user, email.body.chomp)
    issue.save
  end

  def attempt_to_recognize_as_reply(email)
    issue = find_issue_by_reply(email)
    return unless issue

    # find user
    user = User.find_active(:first, :conditions => {:mail => email.from.first})
    user ||= User.anonymous
    # check permission
    return unless user.allowed_to?(:add_issue_notes, issue.project)

    # add the note
    issue.init_journal(user, email.body.chomp)
    issue.save
  end

  def find_issue_by_reply(email)
    in_reply_to = email.header['in-reply-to']
    if in_reply_to
      issue = Issue.find_by_mail_id(in_reply_to.body)
      return issue if issue
    end

    references = email.header['references']
    if references
      references.body.split(/\s+/).each do |message_id|
        issue = Issue.find_by_mail_id(message_id)
        return issue if issue
      end
    end
    return nil
  end

  def add_issue_from(email, tracker_name, target_name)
    # find user
    user = User.find_active(:first, :conditions => {:mail => email.from.first})
    user ||= User.anonymous

    ml, ml_code, msg_id = identify_mail_by_x_ml_header(email.header)
    return unless ml
    projects = ml.mailing_list_trackings.select{|track| track.match?(target_name) }.map(&:project)
    projects.each do |project|
      # check permission
      return unless user.allowed_to?(:add_issues, project)

      tracker = project.trackers.find(:first, :conditions => ['LOWER(name) = LOWER(?)', tracker_name])
      next unless tracker

      subject = email.subject.sub(/\A.*?\[#{Regexp.escape tracker_name}:.+?\]\s*/, '')
      project.issues.create! :subject => subject, :description => email.body, :tracker => tracker,
        :status => IssueStatus.default, :priority => Enumeration::get_values('IPRI').first,
        :author => user, :mailing_list => ml, :mailing_list_code => ml_code, :mail_id => msg_id
    end
  end

  def resolve_issue(email)
    id = email.header['x-redmine-issue-id'].body
    issue = Issue.find(id)
    ml, ml_code, msg_id = identify_mail_by_x_ml_header(email.header)

    unless issue.project.identifier == email.header['x-redmine-project'].body and
      email.subject.include?(issue.subject) and ml == issue.mailing_list and
      email.from.first == issue.author.mail then
      logger.error("cycled email's inconsistance: issue is;\n %s\nbut email is;\n%s" % [issue.to_yaml, email])
      return
    end

    issue.mailing_list_code = ml_code
    issue.mail_id = msg_id
    issue.save!
  end

  # Tries to identify the specified mail by its X-ML-Name and X-Mail-Count header fields.
  # This works for fml and QuickML
  def identify_mail_by_x_ml_header(headers)
    ml = MailingList.find_by_name(headers['x-ml-name'].body)
    return ml ? [ml, Integer(headers['x-mail-count'].body), headers['message-id'].body] : nil
  rescue ArgumentError
    return nil
  end
end
