require 'mongo_mapper'
require 'hpricot'

# describe a review
class Usage

  include MongoMapper::Document

  # this is the  XXX for opinion
  # refers to a combinaison of dimension/rating
  # refers to one or more hard-feature

  key :label, String

  key :user_id, Mongo::ObjectID # the user who recorded first this  usage
  belongs_to :user

  key :knowledge_id, Mongo::ObjectID
  belongs_to :knowlege

  many :opinions
  
  timestamps!

  def display_as() label.gsub(' ', '_').downcase[0.80] end

  def self.similar_to(input)
    input = input.downcase
    Usage.all(:order => "label").select { |u| u.label.downcase.index(input) }.collect(&:label)  
  end

end

