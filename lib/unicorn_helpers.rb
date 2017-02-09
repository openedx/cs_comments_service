module UnicornHelpers

  # Make sure elasticsearch is configured correctly
  def self.exit_on_invalid_index
    begin
      TaskHelpers::ElasticsearchHelper.validate_index(Content::ES_INDEX_NAME)
    rescue => e
      # Magic exit code expected by forum-supervisor.sh for when
      # rake search:validate_index fails
      STDERR.puts "ERROR: ElasticSearch configuration validation failed. "\
           "\"rake search:validate_index\" failed with the following message: #{e.message}"
      exit(101)
    end
  end

end
