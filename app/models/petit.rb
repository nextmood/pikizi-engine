require 'mongo_mapper'

# describe an review of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Petit

  include MongoMapper::Document

  key :label, String
  key :grand_id, Mongo::ObjectID

  belongs_to :grand

end