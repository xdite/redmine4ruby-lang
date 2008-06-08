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

class Changeset < ActiveRecord::Base
  belongs_to :repository
  has_many :changes, :dependent => :delete_all
  has_and_belongs_to_many :issues

  acts_as_event :title => Proc.new {|o| "#{l(:label_revision)} #{o.revision}" + (o.comments.blank? ? '' : (': ' + o.comments))},
                :description => :comments,
                :datetime => :committed_on,
                :author => :committer,
                :url => Proc.new {|o| {:controller => 'repositories', :action => 'revision', :id => o.repository.project_id, :rev => o.revision}}
                
  acts_as_searchable :columns => 'comments',
                     :include => :repository,
                     :project_key => "#{Repository.table_name}.project_id",
                     :date_column => 'committed_on'
  
  validates_presence_of :repository_id, :revision, :committed_on, :commit_date
  validates_uniqueness_of :revision, :scope => :repository_id
  validates_uniqueness_of :scmid, :scope => :repository_id, :allow_nil => true
  
  def revision=(r)
    write_attribute :revision, (r.nil? ? nil : r.to_s)
  end
  
  def comments=(comment)
    write_attribute(:comments, comment.strip)
  end

  def committed_on=(date)
    self.commit_date = date
    super
  end
  
  def project
    repository.project
  end
  
  def after_create
    scan_comment_for_issue_ids
  end
  def scan_comment_for_issue_ids
    return if comments.blank?
    # keywords used to reference issues
    ref_keywords = Setting.commit_ref_keywords.downcase.split(",").collect(&:strip)
    # keywords used to fix issues
    fix_keywords = Setting.commit_fix_keywords.downcase.split(",").collect(&:strip)
    # status and optional done ratio applied
    fix_status = IssueStatus.find_by_id(Setting.commit_fix_status_id)
    done_ratio = Setting.commit_fix_done_ratio.blank? ? nil : Setting.commit_fix_done_ratio.to_i
    
    ref_keyword_any = true if ref_keywords.delete('*')
    fix_keyword_any = true if fix_keywords.delete('*')
    kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw)}.join("|")
    return if kw_regexp.blank? and !ref_keyword_any and !fix_keyword_any

    referenced_issues = []
    comments.scan(%r!
       (?:(#{kw_regexp}) [:\s])?
       ((?:
         \s*
         (?:[,;&]|and)?        # separator
         \s*
         (?:
           \#?\d+            # issue id
          |\[[\w_-]+:\d+\]   # mail number
         )
      )+)
    !ix) do |keyword, ref_texts|
      target_issue_ids = ref_texts.scan(/\#(\d+)/).map(&:first)
      target_issues = repository.project.issues.find_all_by_id(target_issue_ids)

      target_issues += ref_texts.scan(/\[([\w_-]+):(\d+)\]/).map{|name,number|
        repository.project.issues.find(:first, :include => [:mailing_list],
                                       :conditions => ['mailing_lists.name = ? AND mailing_list_code = ?', name, number])
      }
      target_issues = target_issues.compact.uniq

      if ref_keyword_any || keyword && ref_keywords.include?(keyword.downcase)
        referenced_issues += target_issues
      end
      if fix_status
        if ( fix_keyword_any && !(keyword && ref_keywords.include?(keyword.downcase)) ) || 
          ( keyword && fix_keywords.include?(keyword.downcase) ) then
          referenced_issues += target_issues
          # update status of issues
          logger.debug "Issues fixed by changeset #{self.revision}: #{target_issues.map(&:id).join(', ')}." if logger && logger.debug?
          target_issues.each do |issue|
            # the issue may have been updated by the closure of another one (eg. duplicate)
            issue.reload
            # don't change the status is the issue is closed
            next if issue.status.is_closed?
            user = committer_user || User.anonymous
            csettext = "r#{self.revision}"
            if self.scmid && (! (csettext =~ /^r[0-9]+$/))
              csettext = "commit:\"#{self.scmid}\""
            end
            journal = issue.init_journal(user, l(:text_status_changed_by_changeset, csettext))
            issue.status = fix_status
            issue.done_ratio = done_ratio if done_ratio
            issue.save
            Mailer.deliver_issue_edit(journal) if Setting.notified_events.include?('issue_updated')
          end
        end
      end
    end
    
    self.issues = referenced_issues.uniq
  end

  # Returns the Redmine User corresponding to the committer
  def committer_user
    if committer && committer.strip =~ /^([^<]+)(<(.*)>)?$/
      username, email = $1.strip, $3
      u = User.find_by_login(username)
      u ||= User.find_by_mail(email) unless email.blank?
      u
    end
  end
  
  # Returns the previous changeset
  def previous
    @previous ||= Changeset.find(:first, :conditions => ['id < ? AND repository_id = ?', self.id, self.repository_id], :order => 'id DESC')
  end

  # Returns the next changeset
  def next
    @next ||= Changeset.find(:first, :conditions => ['id > ? AND repository_id = ?', self.id, self.repository_id], :order => 'id ASC')
  end
end
