require 'erb'

set :application, "express-hello"
set :scm,         :git
set :repository,  "git://github.com/dakatsuka/express-hello.git"
set :branch,      "master"
set :deploy_via,  :remote_cache
set :deploy_to,   "/home/nodeapp/#{application}"
set :node_path,   "/opt/node-v0.4.9/bin"
set :node_script, "app.js"

set :user, "nodeapp"
set :use_sudo, true
set :default_run_options, :pty => true

role :app, "127.0.0.1"

set :shared_children, %w(log node_modules)

namespace :deploy do
  task :default do
    update
    start
  end

  task :cold do
    update
    start
  end
  
  task :setup, :expect => { :no_release => true } do
    dirs  = [deploy_to, releases_path, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "mkdir -p #{dirs.join(' ')}"
    run "chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
  end
  
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
    run <<-CMD
      rm -rf #{latest_release}/log #{latest_release}/node_modules &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/node_modules #{latest_release}/node_modules
    CMD
  end
  
  task :start, :roles => :app do
    run "#{sudo} restart #{application} || #{sudo} start #{application}"
  end

  task :stop, :roles => :app do
    run "#{sudo} stop #{application}"
  end

  task :restart, :roles => :app do
    start
  end
  
  task :npm, :roles => :app do
    run <<-CMD
      export PATH=#{node_path}:$PATH &&
      cd #{latest_release} &&
      npm install 
    CMD
  end
  
  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART_SCRIPT
description "#{application} upstart script"
start on (local-filesystem and net-device-up)
stop on shutdown
respawn
respawn limit 5 60
script
  chdir #{current_path}
  exec sudo -u #{user} NODE_ENV="production" #{node_path}/node #{node_script} >> log/production.log 2>&1
end script
    UPSTART_SCRIPT

    put upstart_script, "/tmp/#{application}.conf"
    run "#{sudo} mv /tmp/#{application}.conf /etc/init"
  end
end

after 'deploy:setup', 'deploy:write_upstart_script'
after 'deploy:finalize_update', 'deploy:npm'
