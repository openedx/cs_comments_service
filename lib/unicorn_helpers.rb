module UnicornHelpers

  # Make sure elasticsearch is configured correctly
  def self.exit_on_invalid_index
    begin
      TaskHelpers::ElasticsearchHelper.validate_indices
    rescue => e
      # Magic exit code expected by forum-supervisor.sh for when
      # rake search:validate_indices fails
      STDERR.puts "ERROR: ElasticSearch configuration validation failed. "\
           "\"rake search:validate_indices\" failed with the following message: #{e.message}"
      exit(101)
    end
  end

end
