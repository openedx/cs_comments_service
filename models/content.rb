class Content
  
  include Mongoid::Document
  include Mongo::Voteable
  
  field :visible, type: Boolean, default: true
  field :abuse_flaggers, type: Array, default: []
  field :historical_abuse_flaggers, type: Array, default: [] #preserve abuse flaggers after a moderator unflags
  field :author_username, type: String, default: nil
  
  index({_type: 1, course_id: 1, pinned: -1, created_at: -1 }, {background: true} )
  index({_type: 1, course_id: 1, pinned: -1, comment_count: -1, created_at: -1}, {background: true})
  index({_type: 1, course_id: 1, pinned: -1, "votes.point" => -1, created_at: -1}, {background: true})

  index({comment_thread_id: 1, sk: 1}, {sparse: true})
  index({comment_thread_id: 1, endorsed: 1}, {sparse: true})
  index({commentable_id: 1}, {sparse: true, background: true})

  ES_INDEX_NAME = 'content'

  def self.put_search_index_mapping(idx=nil)
    idx ||= self.tire.index
    success = idx.mapping(self.tire.document_type, {:properties => self.tire.mapping})
    unless success
      logger.warn "WARNING! could not apply search index mapping for #{self.name}"
    end
  end

  before_save :set_username
  def set_username
    # avoid having to look this attribute up later, since it does not change
    self.author_username = author.username
  end

  def author_with_anonymity(attr=nil, attr_when_anonymous=nil)
    if not attr
      (anonymous || anonymous_to_peers) ? nil : author
    else
      (anonymous || anonymous_to_peers) ? attr_when_anonymous : author.send(attr)
    end
  end

  def self.flagged
    #return an array of flagged content
    holder = []
    Content.where(:abuse_flaggers.ne => [],:abuse_flaggers.exists => true).each do |c|
      holder << c
    end
    holder
  end

  def self.prolific_metric what, count
    #take a hash of criteria (what) and return a hash of hashes
    #course => user => count

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
  
  def self.summary what
    #take a hash of criteria (what) and return a hash of hashes
    #of total users, votes, comments, endorsements, 
    
    answer = {}
    vote_count = 0
    thread_count = 0
    comment_count = 0
    contributors = []
    content = self.where(what)
    
    content.each do |c|
      contributors << c.author_id
      contributors << c["votes"]["up"]
      contributors << c["votes"]["down"]
      vote_count += c["votes"]["count"]
      if c._type == "CommentThread"
        thread_count += 1
      elsif c._type == "Comment"
        comment_count += 1
      end
    end

    #uniquify contributors
    contributors = contributors.uniq
    
    #assemble the answer and ship
    
    answer["vote_count"] = vote_count
    answer["thread_count"] = thread_count
    answer["comment_count"] = comment_count
    answer["contributor_count"] = contributors.count
    
    answer
  end

end
