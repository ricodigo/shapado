require 'bundler'
APP_ROOT = Bundler.root.to_s
launcher = "cd #{APP_ROOT}; rvm 1.9.2 exec bundle exec"

daily_report = "#{launcher} script/daily_report production"
cleanup = "#{launcher} script/cleanup production"
twitter = "#{launcher} script/import_twitter production"
email = "#{launcher} script/import_email production"

env "PATH", ENV["PATH"]
set :output, "#{APP_ROOT}/log/crontab.log"

every :saturday, :at => "2:50 am" do
  command daily_report
end

every :wednesday, :at => "2:50 am" do
  command cleanup
end

every 5.minutes do
  command twitter
end

every 8.minutes do
  command email
end
