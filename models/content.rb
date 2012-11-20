class Content
  
  include Mongoid::Document
  
  field :visible, type: Boolean, default: true
  field :abuse_flaggers, type: Array, default: []
  field :spoiler_flaggers, type: Array, default: []
  
  def author_with_anonymity(attr=nil, attr_when_anonymous=nil)
    if not attr
      (anonymous || anonymous_to_peers) ? nil : author
    else
      (anonymous || anonymous_to_peers) ? attr_when_anonymous : author.send(attr)
    end
  end
  
end
