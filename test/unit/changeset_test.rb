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

class ChangesetTest < Test::Unit::TestCase
  fixtures :projects, :repositories, :issues, :issue_statuses, :changesets, :changes, :issue_categories, :enumerations, :custom_fields, :custom_values, :users, :members, :trackers
  fixtures :mailing_lists, :mailing_list_trackings, :projects_trackers

  def setup
  end
  
  def test_ref_keywords_any
    Setting.commit_fix_status_id = IssueStatus.find(:first, :conditions => ["is_closed = ?", true]).id
    Setting.commit_fix_done_ratio = '90'
    Setting.commit_ref_keywords = '*'
    Setting.commit_fix_keywords = 'fixes , closes'
    
    c = Changeset.new(:repository => issues(:not_fixed1).project.repository,
                      :committed_on => Time.now,
                      :comments => 'New commit (#102). Fixes #101, [ruby-dev:103]')
    c.scan_comment_for_issue_ids
    
    assert_equal [101, 102, 103], c.issue_ids.sort
    [issues(:not_fixed1), issues(:not_fixed3)].each do |fixed|
      fixed.reload
      assert fixed.closed?
      assert_equal 90, fixed.done_ratio
    end
    assert !issues(:not_fixed2).reload.closed?
  end
  
  def test_ref_keywords_any_line_start
    Setting.commit_ref_keywords = '*'

    c = Changeset.new(:repository => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments => '#1 is the reason of this commit')
    c.scan_comment_for_issue_ids

    assert_equal [1], c.issue_ids.sort
  end

  def test_ref_keywords_any_2
    Setting.commit_fix_status_id = IssueStatus.find(:first, :conditions => ["is_closed = ?", true]).id
    Setting.commit_fix_done_ratio = 100
    Setting.commit_ref_keywords = 'see'
    Setting.commit_fix_keywords = '*'
    
    c = Changeset.new(:repository => issues(:not_fixed1).project.repository,
                      :committed_on => Time.now,
                      :comments => 'New commit #102, [ruby-dev:103]. see #101')
    c.scan_comment_for_issue_ids
    
    assert_equal [101, 102, 103], c.issue_ids.sort
    [issues(:not_fixed2), issues(:not_fixed3)].each do |fixed|
      fixed.reload
      assert fixed.closed?
      assert_equal 100, fixed.done_ratio
    end
    assert !issues(:not_fixed1).reload.closed?
  end

  def test_register_issue_and_close_immediately
    Setting.commit_fix_status_id = IssueStatus.find(:first, :conditions => ["is_closed = ?", true]).id
    Setting.commit_fix_done_ratio = 100
    Setting.commit_ref_keywords = 'see'
    Setting.commit_fix_keywords = '*'
    Enumeration.find_by_opt_and_name('IPRI', 'Normal').update_attribute(:is_default, true)
    
    c = Changeset.new(:repository => issues(:not_fixed1).project.repository,
                      :committed_on => Time.now,
                      :comments => <<-EOS)
* foo.c (function_foo): [Feature request] Foo#bar should be blahblahblah.
* bar.c (function_bar): [Bug] Bar#baz caused SEGV. 
                      EOS
    c.scan_comment_for_issue_ids
    c.issues.sort!{|x,y| x.id <=> y.id}
    
    assert_equal 2, c.issue_ids.length
    assert_equal "Foo#bar should be blahblahblah.", c.issues[0].description
    assert_equal trackers(:feature).id, c.issues[0].tracker_id
    assert_equal "Bar#baz caused SEGV.", c.issues[1].description
    assert_equal trackers(:bug).id, c.issues[1].tracker_id
  end

  def test_previous
    changeset = Changeset.find_by_revision('3')
    assert_equal Changeset.find_by_revision('2'), changeset.previous
  end

  def test_previous_nil
    changeset = Changeset.find_by_revision('1')
    assert_nil changeset.previous
  end

  def test_next
    changeset = Changeset.find_by_revision('2')
    assert_equal Changeset.find_by_revision('3'), changeset.next
  end

  def test_next_nil
    changeset = Changeset.find_by_revision('4')
    assert_nil changeset.next
  end
end
