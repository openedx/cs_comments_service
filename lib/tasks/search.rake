require 'task_helpers'

namespace :search do
  desc 'Indexes content updated in the last N minutes.'
  task :catchup, [:minutes, :index_name, :batch_size, :sleep_time] => :environment do |t, args|
    start_time = Time.now - (args[:minutes].to_i * 60)
    args.with_defaults(:index_name => Content::ES_INDEX_NAME)
    args.with_defaults(:batch_size => 500)
    args.with_defaults(:sleep_time => 0)
    TaskHelpers::ElasticsearchHelper.catchup_index(start_time, args[:index_name], args[:batch_size].to_i, args[:sleep_time].to_i)
  end

  desc 'Rebuilds a new index of all data from the database and then updates alias.'
  task :rebuild_index, [:call_move_alias, :batch_size, :sleep_time] => :environment do |t, args|
    args.with_defaults(:call_move_alias => false)
    args.with_defaults(:batch_size => 500)
    args.with_defaults(:sleep_time => 0)
    alias_name = args[:call_move_alias] ? Content::ES_INDEX_NAME : nil
    TaskHelpers::ElasticsearchHelper.rebuild_index(alias_name, args[:batch_size].to_i, args[:sleep_time].to_i)
  end

  desc 'Generate a new, empty physical index, without bringing it online.'
  task :create_index => :environment do
    TaskHelpers::ElasticsearchHelper.create_index
  end

  desc 'Creates a new search index and points the "content" alias to it'
  task :initialize, [:force] => :environment do |t, args|
    args.with_defaults(:force => false)
    # if the alias doesn't already exist, create the index and move the alias.
    # WARNING: if an index exists with the same name as the intended alias, it
    #   will be deleted.
    TaskHelpers::ElasticsearchHelper.initialize_index(Content::ES_INDEX_NAME, args[:force])
  end

  desc 'Sets/moves an alias to the specified index'
  task :move_alias, [:index, :force_delete] => :environment do |t, args|
    # Forces delete of an index with same name as alias if it exists.
    args.with_defaults(:force_delete => false)
    alias_name = Content::ES_INDEX_NAME
    TaskHelpers::ElasticsearchHelper.move_alias(alias_name, args[:index], args[:force_delete])
  end
end
