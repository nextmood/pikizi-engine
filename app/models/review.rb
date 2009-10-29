require 'mongo_mapper'

class Review
  
  include MongoMapper::Document

  key :type, String
  key :knowledge_url, String
  key :feature_url, String
  key :product_url, String
  key :media_url, String
  key :author_id, String
  key :data, String

  key :updated_at, Time


end