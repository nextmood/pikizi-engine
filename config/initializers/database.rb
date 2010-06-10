# connect to mongo



=begin
MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017, {
   :auto_reconnect => true,
   :logger         => Rails.logger
})
=end

# setup default MM database
MongoMapper.database = "pikizi_mongodb_#{Rails.env}"

if defined?(PhusionPassenger)
   PhusionPassenger.on_event(:starting_worker_process) do |forked|
     MongoMapper.connection.connect_to_master if forked
   end
end

 