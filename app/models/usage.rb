require 'mongo_mapper'
require 'hpricot'

# describe a review
class Usage

  include MongoMapper::Document

  # this is the  XXX for opinion
  # refers to a combinaison of dimension/rating
  # refers to one or more hard-feature

  key :label, String
  key :dimension_rating_weight, Array #  [ [feature_rating_url, 0.5], [feature_rating_url, 0.2], ... [] ]
  key :feature_urls, Array

  key :user_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :user

  key :knowledge_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :knowlege

  timestamps!


end

