MongoMapper.database = "pikizi_mongodb_#{Rails.env}"

if defined?(PhusionPassenger)
   PhusionPassenger.on_event(:starting_worker_process) do |forked|
     MongoMapper.connection.connect_to_master if forked
   end
end


CarrierWave.configure do |config|
  config.grid_fs_database = "pikizi_mongodb_#{Rails.env}"
  config.grid_fs_host = 'localhost'
  config.grid_fs_access_url = "/media/show"
end