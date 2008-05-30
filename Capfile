load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
require 'mongrel_cluster/recipes'
load 'config/deploy'
autoload :ERB, 'erb'

PATH="/opt/csw/bin:/opt/csw/mysql5/bin:/usr/local/bin:/usr/bin:/bin"

namespace :db do
  desc "Generate config/database.yml for production environment after deploy:setup"
  task :init_config, :only => "app" do
    $stderr.print('User name: '); username = $stdin.gets.chomp
    password = Capistrano::CLI.password_prompt("database password:")

    template = ERB.new(File.read("./config/database.yml.erb"))
    config = template.result(binding)

    run "mkdir -p #{shared_path}/config"
    put config, "#{shared_path}/config/database.yml"
  end
  after 'deploy:setup', 'db:init_config'

  desc "Applies config/database.yml for production environment to the deployed code"
  task :apply_config, :only => "app" do
    run <<-"EOS"
      cd #{latest_release}/config && ln -sf #{shared_path}/config/database.yml .
    EOS
  end
  after 'deploy:update_code', 'db:apply_config'

  desc "Prepares backup/ directory"
  task :prepare_backup do
    run "ln -s #{shared_path}/backup #{latest_release}/backup"
  end
  after 'deploy:update_code', 'db:prepare_backup'

  desc "Backup the remote production database"
  task :backup, :roles => :db, :only => { :primary => true } do
    run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env PATH='#{PATH}' #{latest_release}/script/database/backup
    CMD
  end
  before 'deploy:migrate', 'db:backup'

  desc "List the backups of the remote production database"
  task :list_backup do
    run "ls #{shared_path}/backup/"
  end
end

namespace :mail do
  desc 'starts mail receiving daemon'
  task :start do
    run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env RAILS_ENV=production #{latest_release}/script/daemons start
    CMD
  end
  desc 'restarts mail receiving daemon'
  task :restart do
    run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env RAILS_ENV=production #{latest_release}/script/daemons restart
    CMD
  end
  desc 'stops mail receiving daemon'
  task :stop do
    run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env RAILS_ENV=production #{latest_release}/script/daemons stop
    CMD
  end
  task :check do
    run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env RAILS_ENV=production #{latest_release}/script/mail_checker
    CMD
  end
end

desc '[internal]'
task :setup_dirs do
  run <<-"CMD"
    mkdir #{shared_path}/cache 2>/dev/null || true; \
    mkdir #{shared_path}/sessions 2>/dev/null || true; \
    mkdir #{shared_path}/mail 2>/dev/null || true; \
    ln -s #{shared_path}/cache #{latest_release}/tmp/; \
    ln -s #{shared_path}/sessions #{latest_release}/tmp/ \
    ln -s #{shared_path}/mail #{latest_release}/tmp/
  CMD
end
after 'deploy:update_code', :setup_dirs

desc "fixes ths shebang's of script/**/*"
task :fix_shebang do
  run <<-"CMD".gsub(/^ +/, '')
    find #{latest_release}/script -type f -exec #{latest_release}/script/fix_path '{}' ';'
  CMD
end
after 'deploy:update_code', :fix_shebang
