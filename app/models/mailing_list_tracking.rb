class MailingListTracking < ActiveRecord::Base
  belongs_to :project
  belongs_to :mailing_list
  validates_presence_of :project, :mailing_list, :project_selector_pattern

  def match?(selector)
    selector_patterns.any?{|pat| pat == selector}
  end

  private
  def selector_patterns
    @selector_patterns ||= project_selector_pattern.split(/,\s*/)
  end
end
