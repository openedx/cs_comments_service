ENV["SINATRA_ENV"] = "test"

require 'simplecov'
SimpleCov.start
if ENV['CI']=='true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require File.join(File.dirname(__FILE__), '..', 'app')

require 'rack/test'
require 'rspec/its'
require 'rspec/collection_matchers'
require 'sinatra'
require 'yajl'

require 'support/database_cleaner'
require 'support/elasticsearch'
require 'support/factory_bot'
require 'support/rake'
require 'support/matchers'
require 'webmock/rspec'

WebMock.allow_net_connect!

# setup test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

Mongoid.logger.level = Logger::WARN
Mongo::Logger.logger.level = ENV["ENABLE_MONGO_DEBUGGING"] ? Logger::DEBUG : Logger::WARN

Delayed::Worker.delay_jobs = false

def app
  Sinatra::Application
end

TEST_API_KEY = 'comments-service-test-api-key'
CommentService.config[:api_key] = TEST_API_KEY

def set_api_key_header
  current_session.header "X-Edx-Api-Key", TEST_API_KEY
end


RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.example_status_persistence_file_path = ".rspec-test-status"
end

Mongoid.configure do |config|
  config.connect_to "cs_comments_service_test"
end

def parse(text)
  Yajl::Parser.parse text
end

def create_test_user(id)
  User.create!(external_id: id.to_s, username: "user#{id}")
end

# Add the given body of text to the list of blocked texts/hashes.
def block_post_body(body='blocked post')
  body = body.strip.downcase.gsub(/[^a-z ]/, '').gsub(/\s+/, ' ')
  blocked_hash = Digest::MD5.hexdigest(body)
  Content.mongo_client[:blocked_hash].insert_one(hash: blocked_hash)

  # reload the global holding the blocked hashes
  CommentService.blocked_hashes = Content.mongo_client[:blocked_hash].find(nil, projection: {hash: 1}).map do |d|
    d['hash']
  end

  blocked_hash
end

def init_without_subscriptions
  commentable = Commentable.new("question_1")

  users = (1..10).map { |id| create_test_user(id) }
  user = users.first

  thread = CommentThread.new(title: "I can't solve this problem", body: "can anyone help me?", course_id: "1", commentable_id: commentable.id)
  thread.thread_type = :discussion
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
  thread.thread_type = :discussion
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

  thread = CommentThread.new(title: "Our super secret discussion", body: "no one can see us", course_id: "2", commentable_id: commentable.id)
  thread.thread_type = :discussion
  thread.context = :standalone
  thread.author = user
  thread.save!
  user.subscribe(thread)

  thread = CommentThread.new(title: "I don't know what to say", body: "lol", course_id: "2", commentable_id: "something else")
  thread.thread_type = :discussion
  thread.author = users[1]
  thread.save!

  comment = thread.comments.new(body: "i am objectionable", course_id: "2")
  comment.author = users[2]
  comment.abuse_flaggers = [users[3]._id]
  comment.save!

  Comment.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users[2, 9].each { |user| user.vote(c, [:up, :down].sample) }
  end

  CommentThread.all.each do |c|
    user.vote(c, :up) # make the first user always vote up for convenience
    users[2, 9].each { |user| user.vote(c, [:up, :down].sample) }
  end

  block_post_body
end

# this method is used to test results produced using the helper function handle_threads_query
# which is used in multiple areas of the API
def check_thread_result(user, thread, hash, is_json=false)
  expected_keys = %w(id thread_type title body course_id commentable_id created_at updated_at context)
  expected_keys += %w(anonymous anonymous_to_peers at_position_list closed user_id)
  expected_keys += %w(username votes abuse_flaggers tags type group_id pinned)
  expected_keys += %w(comments_count unread_comments_count read endorsed last_activity_at)
  expected_keys += %w(closed_by edit_history)
  # these keys are checked separately, when desired, using check_thread_response_paging.
  actual_keys = hash.keys - [
    "children", "endorsed_responses", "non_endorsed_responses", "resp_skip",
    "resp_limit", "resp_total", "non_endorsed_resp_total"
  ]
  expect(actual_keys.sort).to eq expected_keys.sort

  expect(hash["title"]).to eq thread.title
  expect(hash["body"]).to eq thread.body
  expect(hash["course_id"]).to eq thread.course_id
  expect(hash["anonymous"]).to eq thread.anonymous
  expect(hash["anonymous_to_peers"]).to eq thread.anonymous_to_peers
  expect(hash["commentable_id"]).to eq thread.commentable_id
  expect(hash["at_position_list"]).to eq thread.at_position_list
  expect(hash["closed"]).to eq thread.closed
  expect(hash["closed_by"]).to eq thread.closed_by
  expect(hash["user_id"]).to eq thread.author.id
  expect(hash["username"]).to eq thread.author.username
  expect(hash["votes"]["point"]).to eq thread.votes["point"]
  expect(hash["votes"]["count"]).to eq thread.votes["count"]
  expect(hash["votes"]["up_count"]).to eq thread.votes["up_count"]
  expect(hash["votes"]["down_count"]).to eq thread.votes["down_count"]
  expect(hash["abuse_flaggers"]).to eq thread.abuse_flaggers
  expect(hash["tags"]).to eq []
  expect(hash["type"]).to eq "thread"
  expect(hash["group_id"]).to eq thread.group_id
  expect(hash["pinned"]).to eq thread.pinned?
  expect(hash["endorsed"]).to eq thread.endorsed?
  expect(hash["comments_count"]).to eq thread.comments.length
  edit_history = thread.edit_history.map(&:to_hash).map do |item|
    if is_json
      item.merge("created_at"=>item["created_at"].utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
    else
      item
    end
  end
  expect(hash["edit_history"]).to eq edit_history
  hash["context"] = thread.context

  if is_json
    expect(hash["id"]).to eq thread._id.to_s
    expect(hash["created_at"]).to eq thread.created_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    expect(hash["updated_at"]).to eq thread.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    expect(hash["last_activity_at"]).to eq thread.last_activity_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  else
    expect(hash["created_at"]).to eq thread.created_at
    expect(hash["updated_at"]).to eq thread.updated_at
    expect(hash["last_activity_at"]).to eq thread.last_activity_at
  end

  if user.nil?
    expect(hash["unread_comments_count"]).to eq thread.comments.length
    expect(hash["read"]).to eq false
  else
    expected_unread_cnt = thread.comments.length # initially assume nothing has been read
    read_states = user.read_states.where(course_id: thread.course_id).to_a
    if read_states.length == 1
      read_date = read_states.first.last_read_times[thread.id.to_s]
      if read_date
        thread.comments.each do |c|
          if c.created_at < read_date
            expected_unread_cnt -= 1
          end
        end
        expect(hash["read"]).to eq(read_date >= thread.last_activity_at)
      else
        expect(hash["read"]).to eq false
      end
    end
    expect(hash["unread_comments_count"]).to eq expected_unread_cnt
  end
end

def check_thread_result_json(user, thread, json_response)
  check_thread_result(user, thread, json_response, true)
end

def check_unread_thread_result_json(thread, json_response)
  # when thread is unread we do not check if thread matches the user read states data
  # and explicitly asserts `read` to false; hence pass user=nil
  check_thread_result(nil, thread, json_response, true)
end

def check_thread_response_paging(thread, hash, resp_skip=0, resp_limit=nil, is_json=false, recursive=false)
  case thread.thread_type
    when "discussion"
      check_discussion_response_paging(thread, hash, resp_skip, resp_limit, is_json, recursive)
    when "question"
      check_question_response_paging(thread, hash, resp_skip, resp_limit, is_json, recursive)
  end
end

def check_comment(comment, hash, is_json, recursive = false)
  expect(hash["id"]).to eq(is_json ? comment.id.to_s : comment.id) # Convert from ObjectId if necessary
  expect(hash["body"]).to eq comment.body
  expect(hash["user_id"]).to eq comment.author_id
  expect(hash["username"]).to eq comment.author_username
  expect(hash["endorsed"]).to eq comment.endorsed
  expect(hash["endorsement"]).to eq comment.endorsement
  children = Comment.where({ "parent_id" => comment.id }).sort({ "sk" => 1 }).to_a
  expect(hash["child_count"]).to eq children.length
  if recursive
    expect(hash["children"].length).to eq children.length
    hash["children"].each_with_index do |child_hash, i|
      check_comment(children[i], child_hash, is_json)
    end
  end
end


def check_discussion_response_paging(thread, hash, resp_skip=0, resp_limit=nil, is_json=false, recursive=false)
  if resp_limit.nil?
    resp_limit = CommentService.config["thread_response_default_size"]
  end

  all_responses = thread.root_comments.sort({"sk" => 1}).to_a
  total_responses = all_responses.length
  expect(hash["resp_total"]).to eq total_responses
  expected_responses = resp_limit.nil? ?
                         all_responses.drop(resp_skip) :
                         all_responses.drop(resp_skip).take(resp_limit)
  expect(hash["children"].length).to eq expected_responses.length

  hash["children"].each_with_index do |response_hash, i|
    check_comment(expected_responses[i], response_hash, is_json, recursive)
  end
  expect(hash["resp_skip"].to_i).to eq resp_skip
  expect(hash["resp_limit"].to_i).to eq resp_limit
end

def check_question_response_paging(thread, hash, resp_skip=0, resp_limit=nil, is_json=false, recursive=false)
  all_responses = thread.root_comments.sort({"sk" => 1}).to_a
  endorsed_responses, non_endorsed_responses = all_responses.partition { |resp| resp.endorsed }

  expect(hash["endorsed_responses"].length).to eq endorsed_responses.length
  hash["endorsed_responses"].each_with_index do |response_hash, i|
    check_comment(endorsed_responses[i], response_hash, is_json, recursive)
  end

  hash["non_endorsed_resp_total"] == non_endorsed_responses.length
  expected_non_endorsed_responses = resp_limit.nil? ?
      non_endorsed_responses.drop(resp_skip) :
      non_endorsed_responses.drop(resp_skip).take(resp_limit)
  expect(hash["non_endorsed_responses"].length).to eq expected_non_endorsed_responses.length
  hash["non_endorsed_responses"].each_with_index do |response_hash, i|
    check_comment(expected_non_endorsed_responses[i], response_hash, is_json, recursive)
  end
  total_responses = endorsed_responses.length + non_endorsed_responses.length
  expect(hash["resp_total"]).to eq total_responses

  expect(hash["resp_skip"].to_i).to eq resp_skip
  if resp_limit.nil?
    expect(hash["resp_limit"]).to be_nil
  else
    expect(hash["resp_limit"].to_i).to eq resp_limit
  end
end

def check_thread_response_paging_json(thread, hash, resp_skip=0, resp_limit=nil, recursive=false)
  check_thread_response_paging(thread, hash, resp_skip, resp_limit, true, recursive)
end

# general purpose factory helpers
def make_thread(author, text, course_id, commentable_id, thread_type=:discussion, context=:course)
  thread = CommentThread.new(title: text, body: text, course_id: course_id, commentable_id: commentable_id)
  thread.thread_type = thread_type
  thread.author = author
  thread.context = context
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
    parent.set(child_count: coll.length + 1)
  end
  comment = coll.new(body: text, course_id: parent.course_id)
  comment.author = author
  comment.comment_thread = thread
  comment.save!
  comment
end

def make_standalone_thread(author)
  make_thread(
      author,
      "standalone thread 0",
      DFLT_COURSE_ID,
      "pdq",
      :discussion,
      :standalone
  )
end

# add standalone threads and comments to the @threads and @comments hashes
# using the namespace "standalone t#{index}" for threads and "standalone t#{index} c#{i}" for comments
# takes an index param if used within an iterator, otherwise will namespace using 0 for thread index
# AKA this will overwrite "standalone t0" each time it is called.
def make_standalone_thread_with_comments(author, index=0)
  thread = make_thread(
      author,
      "standalone thread #{index}",
      DFLT_COURSE_ID,
      "pdq",
      :discussion,
      :standalone
  )

  3.times do |i|
    @comments["standalone t#{index} c#{i}"] = make_comment(author, thread, "stand alone comment #{i}")
  end

  @threads["standalone t#{index}"] = thread
end

DFLT_COURSE_ID = "xyz"

def setup_thread_with_comments(author, title,  comment_count=5)
  thread = make_thread author, title, DFLT_COURSE_ID, "pdq"
  comment_count.times do |i|
    make_comment author, thread, Faker::Lorem.sentence
  end
  thread
end

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
  @default_order = 10.times.map { |i| "t#{i}" }.reverse
end

def setup_comments
  User.all.delete
  Content.all.delete

  # create 2 courses
  courses = ["abc", "def"]

  # create 2 users
  users = 2.times.map { |i| create_test_user(i+100) }

  # create a thread author
  author = create_test_user(99)

  for course in courses
    # create 5 threads per course
    5.times do |i|
      thread = make_thread(author, "#{course} t#{i}", course, "pdq")
      # each user comments 5 times per thread
      for user in users
        # flag one random comment from each thread
        flag = rand(5)
        5.times do |j|
          comment = make_comment(user, thread, "c#{course} t#{i} u#{user.id} c#{j}")
          if j == flag
            comment.abuse_flaggers = [1]
            comment.save!
          end
        end
      end
    end
  end
end

# Creates a CommentThread with a Comment, and nested child Comment.
# The author of the thread is subscribed to the thread.
def create_comment_thread_and_comments
  # Create a new comment thread, and subscribe the author to the thread
  thread = create(:comment_thread, :subscribe_author)

  # Create a comment along with a nested child comment
  comment = create(:comment, comment_thread: thread)
  create(:comment, parent: comment)
  comment.set(child_count: 1)

  thread
end

def test_thread_marked_as_read(thread_id, user_id)
  # get thread to assert its "read" status
  get "/api/v1/threads/#{thread_id}", user_id: user_id
  expect(last_response).to be_ok
  retrieved_thread = parse last_response.body
  expect(retrieved_thread["read"]).to eq true
end
