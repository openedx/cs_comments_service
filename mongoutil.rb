def get_db_is_master
  Mongoid::Clients.default.command(isMaster: 1)
end

def is_mongo_primary?
  begin
    response = get_db_is_master
    return response.ok? &&
      response.documents.first['ismaster'] == true
  rescue
    # ignored
  end

  false
end

def is_mongo_available?
  begin
    response = get_db_is_master
    return response.ok? &&
      (response.documents.first['ismaster'] == true ||
       Mongoid::Clients.default.options[:read][:mode] != :primary)
  rescue
    # ignored
  end

  false
end


def reconnect_mongo_primary
  begin
    Mongoid::Clients.default.close
    Mongoid::Clients.default.reconnect
  end unless is_mongo_primary?
end
