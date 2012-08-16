class Content

  include Mongoid::Document
  include Mongoid::TaggableWithContext
  include Mongoid::TaggableWithContext::AggregationStrategy::RealTime

  taggable separator: ',', default: []

  def author_with_anonymity(attr=nil, attr_when_anonymous=nil)
    if not attr
      anonymous ? nil : author
    else
      anonymous ? attr_when_anonymous : author.send(attr)
    end
  end
end
