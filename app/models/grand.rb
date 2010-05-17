require 'mongo_mapper'
require 'petit'

# describe an review of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Grand

  include MongoMapper::Document

  key :label, String

  many :petits
  def destroy() Petit.delete_all(:grand_id => id); super(); end
  
end