set :use_sudo, false
set :application, "redmine"

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/export/home/yugui/redmine"


# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion
set :scm, :git
set :repository, "git://github.com/yugui/redmine4ruby-lang.git"
set :branch, "master"
set :git_shallow_clone, 1
set :deploy_via, :copy
set :copy_compression, :zip

set :mongrel_conf, "#{current_path}/config/mongrel_cluster.yml"
set :mongrel_rails, "env PATH=$PATH:/opt/csw/bin mongrel_rails"
set :rake, "/opt/csw/bin/rake"

role :app, "redmine.ruby-lang.org"
role :web, "redmine.ruby-lang.org"
role :db,  "redmine.ruby-lang.org", :primary => true
