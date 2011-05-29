WD = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

# Use at least one worker per core
worker_processes 1

# Help ensure your application will always spawn in the symlinked "current" directory that Capistrano sets up
working_directory WD

# Listen on a Unix domain socket, use the default backlog size
listen "/tmp/unicorn-shapado.sock", :backlog => 1024

# Nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 30

# Lets keep our process id's in one place for simplicity
pid WD + "/tmp/pids/unicorn.pid"

# Logs are very useful for trouble shooting, use them
stderr_path WD+"/log/unicorn.stderr.log"
stdout_path WD+"/log/unicorn.stdout.log"

# Use "preload_app true"
preload_app true

# GC.respond_to?(:copy_on_write_friendly=) and
#   GC.copy_on_write_friendly = true

before_fork do |server, worker|
  old_pid = WD+'/tmp/pids/unicorn.pid.oldbin'
  if File.exists?(old_pid) && server.pid != old_pid
    pid = File.read(old_pid).to_i

    begin
      Process.kill("QUIT", pid)
      Process.kill(0, pid)
      Process.wait
    rescue Errno::ECHILD, Errno::ESRCH => e
      $stderr.puts ">> Process #{pid} has stopped"
    rescue Errno::ENOENT => e
      $stderr.puts ">> Error killing previous instance. #{e.message}"
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|

  # per-process listener ports for debugging/admin/migrations
  # addr = "127.0.0.1:#{9293 + worker.nr}"
  # server.listen(addr, :tries => -1, :delay => 5, :tcp_nopush => true)

  # the following is *required* for Rails + "preload_app true"

  # if preload_app is true, then you may also want to check and
  # restart any other shared sockets/descriptors such as Memcached,
  # and Redis. TokyoCabinet file handles are safe to reuse
  # between any number of forked children (assuming your kernel
  # correctly implements pread()/pwrite() system calls)

  # Unicorn master is started as root, which is fine, but let's
  # drop the workers to your user/group
  begin
    uid, gid = Process.euid, Process.egid

    target_uid = File.stat(Rails.root).uid
    user = Etc.getpwuid(target_uid).name

    target_gid = File.stat(Rails.root).gid
    group = Etc.getgrgid(target_gid).name

    worker.tmp.chown(target_uid, target_gid)
    if uid != target_uid || gid != target_gid
      Process.initgroups(user, target_gid)
      Process::GID.change_privilege(target_gid)
      Process::UID.change_privilege(target_uid)
    end
  rescue => e
    STDERR.puts "cannot change privileges on #{Rails.env} environment"
    STDERR.puts "  #{e}"
  end

end
