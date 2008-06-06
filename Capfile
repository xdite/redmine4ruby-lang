load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
require 'mongrel_cluster/recipes'
load 'config/deploy'
autoload :ERB, 'erb'

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

  namespace :backup do
    desc "Backups the production database of remote servers"
    task :default, :roles => :db, :only => { :primary => true } do
      run <<-"CMD"
      cd #{latest_release} &&
      /usr/bin/env PATH='#{db_bin_path}' #{latest_release}/script/database/backup
    CMD
    end
    before 'deploy:migrate', 'db:backup:default'

    desc "Prepares backup/ directory"
    task :prepare do
      run "ln -s #{shared_path}/backup #{latest_release}/backup"
    end
    before 'deploy:update_code', 'db:backup:prepare'

    desc "List the backups of the remote production database"
    task :list do
      run "ls #{shared_path}/backup/"
    end
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
  after 'deploy:update', 'mail:restart'

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

  task :list do
    run <<-"CMD"
      ls #{latest_release}/tmp/mail
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
    ln -s #{shared_path}/sessions #{latest_release}/tmp/; \
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
