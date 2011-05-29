RAILS_ROOT = ENV["RAILS_ROOT"] || ENV["PWD"] || File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
rails_env = ENV["RAILS_ENV"] || 'production'

puts ">> Starting bluepill with RAILS_ROOT=#{RAILS_ROOT} and RAILS_ENV=#{rails_env}"

Bluepill.application("shapado", :log_file => RAILS_ROOT + "/log/bluepill.log") do |app|
  app.process("unicorn-shapado") do |process|
    process.pid_file = File.join(RAILS_ROOT, 'tmp', 'pids', 'unicorn.pid')
    process.working_dir = RAILS_ROOT

    process.start_command = "unicorn_rails -Dc #{RAILS_ROOT}/config/unicorn/unicorn.rb -E #{rails_env}"
    process.stop_command = "kill -QUIT {{PID}}"
    process.restart_command = "kill -USR2 {{PID}}"

    process.start_grace_time = 8.seconds
    process.stop_grace_time = 5.seconds
    process.restart_grace_time = 13.seconds

    process.monitor_children do |child_process|
      child_process.stop_command = "kill -QUIT {{PID}}"

      child_process.checks :mem_usage, :every => 15.seconds, :below => 165.megabytes, :times => [3,4], :fires => :stop
      child_process.checks :cpu_usage, :every => 15.seconds, :below => 90, :times => [3,4], :fires => :stop
    end
  end
end

