require_relative '../task_helpers'

namespace :search do
  desc 'Indexes content updated in the last N minutes.'
  task :catchup, [:minutes, :batch_size] => :environment do |t, args|
    start_time = Time.now - (args[:minutes].to_i * 60)
    args.with_defaults(:batch_size => 500)
    TaskHelpers::ElasticsearchHelper.catchup_indices(start_time, args[:batch_size].to_i)
  end

  desc 'Rebuilds new indices of all data from the database.'
  task :rebuild_indices, [:batch_size, :extra_catchup_minutes] => :environment do |t, args|
    args.with_defaults(:batch_size => 500)
    args.with_defaults(:extra_catchup_minutes => 5) # additional catchup time in minutes

    TaskHelpers::ElasticsearchHelper.rebuild_indices(
        args[:batch_size].to_i,
        args[:extra_catchup_minutes].to_i
    )
  end

  desc 'Delete current used or all indices.'
  task :delete_indices, [:delete_all_indices] => :environment do |t, args|
    args.with_defaults(:delete_all_indices => false)
    TaskHelpers::ElasticsearchHelper.delete_indices(args[:delete_all_indices])
  end

  desc 'Creates a new search indices'
  task :initialize, [:force_new_index] => :environment do |t, args|
    # When force_new_index is true, a fresh index for "content" alias is created even if the
    # "content" alias already exists.
    args.with_defaults(:force_new_index => false)
    # WARNING: if "content" is an index and not an alias, it will be deleted and recreated
    #  no matter what is supplied for the force argument
    TaskHelpers::ElasticsearchHelper.initialize_indices(args[:force_new_index])
  end

  desc 'Validates that the "content" alias exists with expected field mappings and types.'
  task :validate_indices => :environment do
    TaskHelpers::ElasticsearchHelper.validate_indices
  end

end
