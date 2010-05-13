MongoMapper.database = "pikizi_mongodb_#{Rails.env}"

#MongoMapper.database = "pikizi_mongodb_development"

if defined?(PhusionPassenger)
   PhusionPassenger.on_event(:starting_worker_process) do |forked|
     MongoMapper.connection.connect_to_master if forked
   end
end
