require 'task_helpers'

namespace :search do
  desc 'Indexes content updated in the last N minutes.'
  task :catchup, [:minutes] => :environment do |t, args|
    start_time = Time.now - (args[:minutes].to_i * 60)

    [Comment, CommentThread].each do |model|
      model.where(:updated_at.gte => start_time).import(index: Content::ES_INDEX_NAME)
    end
  end

  desc 'Reindex all data from the database'
  task :reindex, [:index] => :environment do |t, args|
    args.with_defaults(:index => Content::ES_INDEX_NAME)
    [Comment, CommentThread].each do |model|
      model.import(index: args[:index])
    end
  end

  desc 'Generate a new, empty physical index, without bringing it online.'
  task :create_index => :environment do
    TaskHelpers::ElasticsearchHelper.create_index
  end

  desc 'Creates a new search index and points the "content" alias to it'
  task :initialize => :environment do
    index = TaskHelpers::ElasticsearchHelper.create_index
    TaskHelpers::ElasticsearchHelper.move_alias(Content::ES_INDEX_NAME, index)
  end

  desc 'Sets/moves an alias to the specified index'
  task :move_alias, [:alias, :index] => :environment do |t, args|
    TaskHelpers::ElasticsearchHelper.move_alias(args[:alias], args[:index])
  end
end
