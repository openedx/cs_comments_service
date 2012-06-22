require 'active_record'
require 'thumbs_up'

class User < ActiveRecord::Base
  acts_as_voter

end
