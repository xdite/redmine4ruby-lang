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

    run "mkdir -p #{deploy_to}/shared/config"
    put config, "#{deploy_to}/shared/config/database.yml"
  end
  after 'deploy:setup', 'db:init_config'

  desc "Applies config/database.yml for production environment to the deployed code"
  task :apply_config, :only => "app" do
    run <<-"EOS"
      cd #{release_path}/config && ln -sf #{deploy_to}/shared/config/database.yml .
    EOS
  end
  after 'deploy:update_code', 'db:apply_config'

  desc "Prepares backup/ directory"
  task :prepare_backup do
    run "ln -s #{deploy_to}/shared/backup #{release_path}/backup"
  end
  after 'deploy:update_code', 'db:prepare_backup'

  desc "Backup the remote production database"
  task :backup, :roles => :db, :only => { :primary => true } do
    run "env PATH='#{PATH}' #{release_path}/script/database/backup"
  end
  before 'deploy:migrate', 'db:backup'

  desc "List the backups of the remote production database"
  task :list_backup do
    run "ls #{deploy_to}/shared/backup/"
  end
end

desc '[internal]'
task :setup_dirs do
  run <<-"CMD"
    cd #{release_path}
    mkdir #{deploy_to}/shared/cache || true
    mkdir #{deploy_to}/shared/sessions || true
    ln -s #{deploy_to}/shared/cache #{release_path}/tmp/cache
    ln -s #{deploy_to}/shared/sessions #{release_path}/tmp/sessions
  CMD
end
after 'deploy:update_code', :setup_dirs
