require_relative '../task_helpers'

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
  task :rebuild_index, [:call_move_alias, :batch_size, :sleep_time, :extra_catchup_minutes] => :environment do |t, args|
    args.with_defaults(:call_move_alias => true)
    args.with_defaults(:batch_size => 500)
    args.with_defaults(:sleep_time => 0)  # sleep time between batches in seconds
    args.with_defaults(:extra_catchup_minutes => 5) # additional catchup time in minutes
    alias_name = args[:call_move_alias] === true ? Content::ES_INDEX_NAME : nil
    TaskHelpers::ElasticsearchHelper.rebuild_index(
        alias_name,
        args[:batch_size].to_i,
        args[:sleep_time].to_i,
        args[:extra_catchup_minutes].to_i
    )
  end

  desc 'Generate a new, empty physical index, without bringing it online.'
  task :create_index => :environment do
    TaskHelpers::ElasticsearchHelper.create_index
  end

  desc 'Creates a new search index and points the "content" alias to it'
  task :initialize, [:force_new_index] => :environment do |t, args|
    # When force_new_index is true, a fresh index for "content" alias is created even if the
    # "content" alias already exists.
    args.with_defaults(:force_new_index => false)
    # WARNING: if "content" is an index and not an alias, it will be deleted and recreated
    #  no matter what is supplied for the force argument
    TaskHelpers::ElasticsearchHelper.initialize_index(Content::ES_INDEX_NAME, args[:force_new_index])
  end

  desc 'Updates field mappings for the given index.'
  task :put_mappings, [:index] => :environment do |t, args|
    args.with_defaults(:index => Content::ES_INDEX_NAME)
    TaskHelpers::ElasticsearchHelper.put_mappings(args[:index])
  end

  desc 'Sets/moves an alias to the specified index'
  task :move_alias, [:index, :force_delete] => :environment do |t, args|
    # Forces delete of an index with same name as alias if it exists.
    args.with_defaults(:force_delete => false)
    alias_name = Content::ES_INDEX_NAME
    TaskHelpers::ElasticsearchHelper.move_alias(alias_name, args[:index], args[:force_delete])
  end

  desc 'Validates that the "content" alias exists with expected field mappings and types.'
  task :validate_index => :environment do
    TaskHelpers::ElasticsearchHelper.validate_index(Content::ES_INDEX_NAME)
  end

end
