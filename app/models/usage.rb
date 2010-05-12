require 'mongo_mapper'
require 'hpricot'

# describe a review
class Usage

  include MongoMapper::Document

  # this is the  XXX for opinion
  # refers to a combinaison of dimension/rating
  # refers to one or more hard-feature

  key :label, String

  key :user_id, BSON::ObjectID # the user who recorded first this  usage
  belongs_to :user

  key :knowledge_id, BSON::ObjectID
  belongs_to :knowlege

  key :nb_opinions, Integer, :default => 0
  def self.compute_nb_opinions() Usage.all.each(&:compute_nb_opinions) end
  def compute_nb_opinions() update_attributes(:nb_opinions => Opinion.count(:usage_ids => id)) end
  def opinions() Opinion.all(:usage_ids => id) end
  
  timestamps!

  def display_as() label.gsub(' ', '_').downcase[0.80] end

  def self.similar_to(input)
    input = input.downcase
    Usage.all(:order => "label").select { |u| u.label.downcase.index(input) }.collect(&:label)  
  end

end

