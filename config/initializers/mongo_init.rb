require 'mongo_mapper'

MongoMapper.database = case RAILS_ENV
  when "development" then "pikizi_mongodb_development"
  when "test" then "pikizi_mongodb_test"
  when "production" then "pikizi_mongodb_production"
end