class Content

  include Mongoid::Document
  
  def author_with_anonymity(attr=nil, attr_when_anonymous=nil)
    if not attr
      (anonymous || anonymous_to_peers) ? nil : author
    else
      (anonymous || anonymous_to_peers) ? attr_when_anonymous : author.send(attr)
    end
  end
end
