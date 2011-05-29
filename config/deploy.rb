set :application, "shapado"
set :asset_packager, "jammit"

task :staging do |t|
  set :repository, "git://github.com/ricodigo/shapado.git"
  set :branch, "origin/next"
  set :rails_env, :production
  set :unicorn_workers, 1
  role :web, "metali.co"
  role :app, "metali.co"
  role :db,  "metali.co", :primary => true
end

namespace :deploy do
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "echo '#{`git describe`}' > #{current_path}/public/version.txt"

    assets.compass
    assets.package

    #magent.restart
    bluepill.restart
  end
end

require 'ricodigo_capistrano_recipes'

set(:websocket_remote_config) { "#{shared_path}/config/pills/websocket.pill"}
namespace :websocket do
  desc "Init websocket with bluepill"
  task :init do
    rvmsudo "bluepill load #{websocket_remote_config}"
  end

  desc "Start websocket with bluepill"
  task :start do
    rvmsudo "bluepill websocket start"
  end

  desc "Restart websocket with bluepill"
  task :restart do
    websocket.stop
    websocket.start
  end

  desc "Stop websocket with bluepill"
  task :stop do
    rvmsudo "bluepill websocket stop"
  end

  desc "Display the bluepill status"
  task :status do
    rvmsudo "bluepill websocket status"
  end

  desc "Stop websocket and quit bluepill"
  task :quit do
    rvmsudo "bluepill websocket stop"
    rvmsudo "bluepill websocket quit"
  end
end

