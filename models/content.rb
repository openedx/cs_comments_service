class Content

  include Mongoid::Document

  def author_with_anonymity(attr=nil, attr_when_anonymous=nil)
    if not attr
      (anonymous || anonymous_to_peers) ? nil : author
    else
      (anonymous || anonymous_to_peers) ? attr_when_anonymous : author.send(attr)
    end
  end

  def self.prolific_metric what
    #take a hash of criteria (where) and return a hash of hashes
    #course => user => count

    count = 10

    contributors = {}

    map =  "function(){emit(this.author_id,1)}"
    reduce  =  "function(k, vals) { var sum = 0; for(var i in vals) sum += vals[i]; return sum; }"

    contributors = []
    self.where(what).map_reduce(map,reduce).out(replace: "results").each do |d|
      contributors << d
    end

    #now sort and limit them

    #first sort destructively
    contributors.sort! {|a,b| -a["value"] <=> -b["value"]}
    #then trim it
    contributors = contributors[0..(count - 1)]

    contributors

  end
end
