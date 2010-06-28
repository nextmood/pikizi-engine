# Availability is a set of valid prices by merchant for this product
class Synonym
  include MongoMapper::Document

  key :knowledge_id, BSON::ObjectID, :index => true
  belongs_to :knowledge

  key :object_classname, String
  key :object_id, BSON::ObjectId

  key :matches, Array # an array of string mapping  this object :size >= 1

  def add_entry(knowledge_id, object, first_match)
    Synonym.create(:knowledge_id => knowledge_id,
                   :object_classname => object.class.to_s,
                   :object_id => object.id,
                   :matches => [first_match])
  end

  def label() matches.first  end

  def resolve(knowledge_id, search_string, options={})
    Synonym.all(:knowledge_id => knowledge_id, :matches => search_string)
  end

end

