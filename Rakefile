# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/switchtower.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

namespace :db do
  task :dump do
    abcs = ActiveRecord::Base.connection = ActiveRecord::Base.configrations[RAILS_ENV]
  end
end

task 'load-ml' do
  require 'config/environment'
  ActiveRecord::Base.establish_connection
  ruby_dev = MailingList.create! :name => 'ruby-dev', :address => 'ruby-dev@local.yugui.jp', :locale => 'ja'
  ruby_core = MailingList.create! :name => 'ruby-core', :address => 'ruby-core@local.yugui.jp', :locale => 'en'
  redmine = MailingList.create! :name => 'redmine', :address => 'redmine@local.yugui.jp', :locale => 'en'

  proj = Project.find_by_identifier("ruby-19")
  proj.mailing_list_trackings.create! :mailing_list => ruby_dev, :project_selector_pattern => 'trunk'
  proj.mailing_list_trackings.create! :mailing_list => ruby_core, :project_selector_pattern => 'trunk'
end
