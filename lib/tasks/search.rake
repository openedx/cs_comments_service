require 'task_helpers'

namespace :search do
  desc 'Indexes content updated in the last N minutes.'
  task :catchup, [:minutes] => :environment do |t, args|
    start_time = Time.now - (args[:minutes].to_i * 60)

    [Comment, CommentThread].each do |model|
      model.where(:updated_at.gte => start_time).import(index: Content::ES_INDEX_NAME)
    end
  end

  desc 'Rebuilds a new index of all data from the database and then updates alias.'
  task :rebuild_index, [:call_move_alias] => :environment do |t, args|
    args.with_defaults(:call_move_alias => false)
    alias_name = args[:call_move_alias] ? Content::ES_INDEX_NAME : nil
    TaskHelpers::ElasticsearchHelper.rebuild_index(alias_name)
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
  task :move_alias, [:index, :force_delete] => :environment do |t, args|
    # Forces delete of an index with same name as alias if it exists.
    args.with_defaults(:force_delete => false)
    alias_name = Content::ES_INDEX_NAME
    TaskHelpers::ElasticsearchHelper.move_alias(alias_name, args[:index], args[:force_delete])
  end
end
