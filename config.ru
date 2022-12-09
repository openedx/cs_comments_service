# It is possible that the rack time out here is set to a different value than
# on the edx-platform django_comment_client timeout. An attempt was made to
# move these two values closer together (5s django_client_comment, 6s 
# cs_comments_service from 20). This resulted in more reported timeout errors
# on the cs_comments_service side which better reflected the timeout errors the
# django_comment_client. On the downside, the shorter timeout lead to less time 
# for processing longer queries in the background. The timeout has been set back
# to 20s. Until these slow queries that benefit from being cached in the 
# background are resolved, reducing the timeout is not suggested. 
# More conversation at https://github.com/openedx/cs_comments_service/pull/146
# -Nov 18th, 2015

puts "Loading config.ru."

require "rack-timeout"
use Rack::Timeout

require "mongoid"
use Mongoid::QueryCache::Middleware

require './app'
run Sinatra::Application
