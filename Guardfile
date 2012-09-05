# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'passenger', :cli => '--daemonize --port 4567 --environment development' do
  watch('app.rb')
  watch(%|api/.*\.rb|)
  watch(%|lib/.*\.rb|)
  watch(%|models/.*\.rb|)
  watch(%|config/.*\.rb|)
end
