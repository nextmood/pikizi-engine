require 'mongo_mapper'

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Opinion < Root
  
  include MongoMapper::Document


  key :feature_idurl, String # the reference to a feature in the model
  key :label, String # summary of the review
  key :_type, String # class management

  key :review_id, Mongo::ObjectID # the review where this opinion was extracted
  belongs_to :review

  timestamps!


  def self.is_main_document() true end



  def self.generate_xml

  end

  def is_rating?() false end

end


class Rating < Opinion


  key :min_rating, Float
  key :max_rating, Float
  key :rating, Float



  def is_valid?() min_rating and max_rating and rating end

  def to_html() "#{rating} in [#{min_rating}, #{max_rating}]" end

  def rating_01() Root.rule3(rating, min_rating, max_rating) end

  def is_rating?() true end

end

class Comparator < Opinion

  key :operator_type, String
  key :predicate, String

  def to_html() "#{operator_type} predicate=#{predicate}:#{label}" end

  def is_valid?() ["best", "worse", "same"].include?(operator_type) and !Root.is_empty(predicate)  end

  def self.create_from_xml(feature_idurl, operator_type, xml_node)
    self.create(:feature_idurl => feature_idurl,
                               :operator_type => operator_type,
                               :predicate => xml_node["predicate"],
                               :label => xml_node.content.strip)
  end
  

end


class Tip < Opinion

  key :usage, String
  key :intensity, Float

  def to_html() "usage=#{usage}, i=#{intensity}:#{label}" end

  def is_valid?() !Root.is_empty(usage) and !Root.is_empty(intensity) end

end