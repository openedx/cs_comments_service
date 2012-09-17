# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Sample template for guard-unicorn
#
# Usage:
#     guard :unicorn, <options hash>
#
# Possible options:
# * :daemonize (default is true) - should the Unicorn server start daemonized?
# * :config_file (default is "config/unicorn.rb") - the path to the unicorn file
# * :pid_file (default is "tmp/pids/unicorn.pid") - the path to the unicorn pid file
guard :unicorn, :daemonize => false, :port => 4567 do
  watch('app.rb')
  watch(%|api/.*\.rb|)
  watch(%|lib/.*\.rb|)
  watch(%|models/.*\.rb|)
  watch(%|config/.*\.rb|)
end
