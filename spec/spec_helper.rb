ENV["SINATRA_ENV"] = "test"
require 'simplecov'
SimpleCov.start

require File.join(File.dirname(__FILE__), '..', 'app')

require 'sinatra'
require 'rack/test'
require 'yajl'
require 'database_cleaner'

# setup test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

Delayed::Worker.delay_jobs = false

def app
  Sinatra::Application
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.before(:each) do
    Mongoid::IdentityMap.clear
    DatabaseCleaner.clean
    [CommentThread, Comment].each do |class_|
      class_.tire.index.delete
      class_.create_elasticsearch_index
    end
  end
end

Mongoid.configure do |config|
  config.connect_to "cs_comments_service_test"
end

def parse(text)
  Yajl::Parser.parse text
end

def create_test_user(id)
  User.create!(external_id: id.to_s, username: "user#{id}", email: "user#{id}@test.com")
end

def init_without_subscriptions

  [Comment, CommentThread, User, Notification, Subscription, Activity, Delayed::Backend::Mongoid::Job].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)
  Content.mongo_session[:blocked_hash].drop
  Tire.index 'comment_threads' do delete end
  CommentThread.create_elasticsearch_index
  
  commentable = Commentable.new("question_1")

  users = (1..10).map{|id| create_test_user(id)}
  user = users.first

  thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: commentable.id)
  thread.author = user
  thread.save!
  user.subscribe(thread)

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user
  comment2.comment_thread = thread
  comment2.save!

  comment = thread.comments.new(body: "see the textbook on page 69. it's quite similar", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "thank you!", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!

  thread = CommentThread.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2", commentable_id: commentable.id)
  thread.author = user
  thread.save!
  user.subscribe(thread)

  comment = thread.comments.new(body: "how do you know?", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "because blablabla", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!
  comment = thread.comments.new(body: "no wonder I can't solve it", course_id: "1")
  comment.author = user
  comment.save!
  comment1 = comment.children.new(body: "+1", course_id: "1")
  comment1.author = user
  comment1.comment_thread = thread
  comment1.save!

  thread = CommentThread.new(title: "I don't know what to say", body: "lol", course_id: "2", commentable_id: "something else")
  thread.author = users[1]
  thread.save!

  comment = thread.comments.new(body: "i am objectionable", course_id: "2")
  comment.author = users[2]
  comment.abuse_flaggers = [users[3]._id]
  comment.save!

  Comment.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users[2,9].each {|user| user.vote(c, [:up, :down].sample)}
  end

  CommentThread.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users[2,9].each {|user| user.vote(c, [:up, :down].sample)}
  end

  Content.mongo_session[:blocked_hash].insert(hash: Digest::MD5.hexdigest("blocked post"))
  # reload the global holding the blocked hashes
  CommentService.blocked_hashes = Content.mongo_session[:blocked_hash].find.select(hash: 1).each.map {|d| d["hash"]}

end

def init_with_subscriptions
  [Comment, CommentThread, User, Notification, Subscription, Activity, Delayed::Backend::Mongoid::Job].each(&:delete_all).each(&:remove_indexes).each(&:create_indexes)

  Tire.index 'comment_threads' do delete end
  CommentThread.create_elasticsearch_index

  user1 = create_test_user(1)
  user2 = create_test_user(2)

  user2.subscribe(user1)

  commentable = Commentable.new("question_1")
  user1.subscribe(commentable)
  user2.subscribe(commentable)

  thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: commentable.id)
  thread.author = user1
  user1.subscribe(thread)
  user2.subscribe(thread)
  thread.save!

  thread = thread.reload

  comment = thread.comments.new(body: "this problem is so easy", course_id: "1")
  comment.author = user2
  comment.save!
  comment1 = comment.children.new(body: "not for me!", course_id: "1")
  comment1.author = user1
  comment1.comment_thread = thread
  comment1.save!
  comment2 = comment1.children.new(body: "not for me neither!", course_id: "1")
  comment2.author = user2
  comment2.comment_thread = thread
  comment2.save!

  thread = CommentThread.new(title: "This problem is wrong", body: "it is unsolvable", course_id: "2", commentable_id: commentable.id)
  thread.author = user2
  user2.subscribe(thread)
  thread.save!

  thread = CommentThread.new(title: "I don't know what to say", body: "lol", course_id: "2", commentable_id: "something else")
  thread.author = user1
  thread.save!
end

# this method is used to test results produced using the helper function handle_threads_query
# which is used in multiple areas of the API
def check_thread_result(user, thread, json_response, check_comments=false, is_search=false)
  expected_keys = %w(id title body course_id commentable_id created_at updated_at)
  expected_keys += %w(anonymous anonymous_to_peers at_position_list closed user_id)
  expected_keys += %w(username votes abuse_flaggers tags type group_id pinned)
  expected_keys += %w(comments_count unread_comments_count read endorsed)
  if is_search
    expected_keys += %w(highlighted_body highlighted_title)
  end
  # the "children" key is not always present - depends on the invocation + test use case.
  # exclude it from this check - if check_comments is set, we'll assert against it later
  actual_keys = json_response.keys - ["children"]
  actual_keys.sort.should == expected_keys.sort

  json_response["title"].should == thread.title
  json_response["body"].should == thread.body
  json_response["course_id"].should == thread.course_id 
  json_response["anonymous"].should == thread.anonymous 
  json_response["anonymous_to_peers"].should == thread.anonymous_to_peers 
  json_response["commentable_id"].should == thread.commentable_id 
  json_response["created_at"].should == thread.created_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  json_response["updated_at"].should == thread.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ") 
  json_response["at_position_list"].should == thread.at_position_list 
  json_response["closed"].should == thread.closed 
  json_response["id"].should == thread._id.to_s
  json_response["user_id"].should == thread.author.id
  json_response["username"].should == thread.author.username
  json_response["votes"]["point"].should == thread.votes["point"] 
  json_response["votes"]["count"].should == thread.votes["count"] 
  json_response["votes"]["up_count"].should == thread.votes["up_count"] 
  json_response["votes"]["down_count"].should == thread.votes["down_count"] 
  json_response["abuse_flaggers"].should == thread.abuse_flaggers
  json_response["tags"].should == []
  json_response["type"].should == "thread"
  json_response["group_id"].should == thread.group_id
  json_response["pinned"].should == thread.pinned?
  json_response["endorsed"].should == thread.endorsed?
  if check_comments
    # warning - this only checks top-level comments and may not handle all possible sorting scenarios
    # proper composition / ordering of the children is currently covered in models/comment_thread_spec. 
    # it also does not check for author-only results (e.g. user active threads view)
    # author-only is covered by a test in api/user_spec.
    root_comments = thread.root_comments.sort(_id:1).to_a
    json_response["children"].should_not be_nil
    json_response["children"].length.should == root_comments.length
    json_response["children"].each_with_index { |v, i| 
      v["body"].should == root_comments[i].body
      v["user_id"].should == root_comments[i].author_id
      v["username"].should == root_comments[i].author_username
    }
  end
  json_response["comments_count"].should == thread.comments.length

  if user.nil?
    json_response["unread_comments_count"].should == thread.comments.length
    json_response["read"].should == false 
  else
    expected_unread_cnt = thread.comments.length # initially assume nothing has been read
    read_states = user.read_states.where(course_id: thread.course_id).to_a
    if read_states.length == 1
      read_date = read_states.first.last_read_times[thread.id.to_s]
      if read_date
        thread.comments.each do |c|
          if c.author != user and c.updated_at < read_date
            expected_unread_cnt -= 1
          end
        end
        json_response["read"].should == (read_date >= thread.updated_at)
      else
        json_response["read"].should == false
      end
    end
    json_response["unread_comments_count"].should == expected_unread_cnt
  end
end


# general purpose factory helpers
def make_thread(author, text, course_id, commentable_id)
  thread = CommentThread.new(title: text, body: text, course_id: course_id, commentable_id: commentable_id)
  thread.author = author
  thread.save!
  thread
end

def make_comment(author, parent, text)
  if parent.is_a?(CommentThread)
    coll = parent.comments
    thread = parent
  else
    coll = parent.children
    thread = parent.comment_thread
  end
  comment = coll.new(body: text, course_id: parent.course_id)
  comment.author = author
  comment.comment_thread = thread
  comment.save!
  comment
end

DFLT_COURSE_ID = "xyz"

def setup_10_threads
  User.all.delete
  Content.all.delete

  @threads = {}
  @comments = {}
  @users = {}
  10.times do |i|
    author = create_test_user(i+100)
    @users["u#{i+100}"] = author
    thread = make_thread(author, "t#{i}", DFLT_COURSE_ID, "pdq")
    @threads["t#{i}"] = thread
    5.times do |j|
      comment = make_comment(author, thread, "t#{i} c#{j}")
      @comments["t#{i} c#{j}"] = comment
    end
  end
  @default_order = 10.times.map {|i| "t#{i}"}.reverse
end
