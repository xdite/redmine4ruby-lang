autoload :ERB, 'erb'

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
set :repository, "ssh://git.yugui.jp:422/var/git/redmine.git"
set :branch, "master"
set :git_shallow_clone, 1
set :deploy_via, :copy
set :copy_compression, :zip

set :mongrel_conf, "#{current_path}/config/mongrel_cluster.yml"
set :rake, "/opt/csw/bin/rake"
set :mongrel_rails, "/opt/csw/bin/mongrel_rails"

role :app, "redmine.ruby-lang.org"
role :web, "redmine.ruby-lang.org"
role :db,  "redmine.ruby-lang.org", :primary => true


task :init_database_config, :only => "app" do
  $stderr.print('User name: '); username = $stdin.gets.chomp
  password = Capistrano::CLI.password_prompt("database password:")

  template = ERB.new(File.read("./config/database.yml.erb"))
  config = template.result(binding)

  run "mkdir -p #{deploy_to}/shared/config"
  put config, "#{deploy_to}/shared/config/database.yml"
end
after 'deploy:setup', :init_database_config
task :configure_database, :only => "app" do
  run <<-EOS
    cd #{release_path}/config && ln -sf #{deploy_to}/shared/config/database.yml .
  EOS
end
after 'deploy:update_code', :configure_database
