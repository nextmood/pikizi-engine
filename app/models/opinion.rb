require 'mongo_mapper'
require 'treetop'


class RelatedTo
  include MongoMapper::EmbeddedDocument
end

class RelatedToSpecification < RelatedTo
  key :specification_id, Mongo::ObjectID
end

class RelatedToSpecificationTag < RelatedToSpecification
  key :tag_idurl, String
end

class RelatedToDimension < RelatedTo
  key :dimension_id, Mongo::ObjectID
end

class ProductsFilter
  include MongoMapper::EmbeddedDocument  
end

class ProductByLabel < ProductsFilter
  key :product_id, Mongo::ObjectID
end

class ProductsBySpec < ProductsFilter
  key :specification_id, Mongo::ObjectID
  key :list_or_filters, Array, :default =>[] # list of filter for the spec   if a or/and expression
end

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Opinion < Root
  
  include MongoMapper::Document


  key :feature_rating_idurl, String # the reference to a feature rating in the model   (rating dimension)
  key :label, String # summary of the opinion
  key :_type, String # class management
  key :usage, String
  key :extract, String
  key :value_oriented, Boolean
  key :validated_by_creator, Boolean, :default => false

  key :review_id, Mongo::ObjectID # the review where this opinion was extracted
  belongs_to :review

  key :user_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :user

  key :paragraph_id, Mongo::ObjectID # from which paragraph (if any) this opinion was extracted
  belongs_to :paragraph

  key :product_ids, Array # an Array pg Mongo Object Id defining the products related to this opinion
  many :products, :in => :product_ids

  key :conjonction_product_referent, Array, :default => [] # an array of ProductsFilter
  key :conjonction_features_related, Array, :default => [] # an array of RelatedTo

  timestamps!

  def self.parse
    Treetop.load "./app/models/opinion"
    parser = OpinionGrammarParser.new
    [ "iphone is very good",
      "all products are mixed",
      "products with nb pixel of camera > 3mpx are very good" ,
      "hardware of iphone is mixed",
      "droid worse than iphone",
      "droid and nexus are very bad" ,
      "droid and nexus and iphone are same",
      "iphone ranked first",
      "nexus rated 4 between 0 and 5",
      "droid better than all products",
      "camera of iphone and droid worse than products with camera nb pixel > 3mpx and products compatible with carriers att and sprint" ,
      "iphone and similar_to iphone same as products compatible with carriers att or sprint and products with brand apple"
    ].each do |expression|
      if result = parser.parse(expression)
        puts "#{expression.inspect} --> #{result.tom}"
      else
        puts "******* failure  parsing #{expression.inspect}"
      end
    end
    true
  end

  def self.is_main_document() true end

  def to_html(options={}) "feature_rating_idurl=#{feature_rating_idurl} label=#{label}, class=#{_type} " end


  def self.generate_xml

  end

  def is_rating?() false end

  def to_xml_bis
    node_opinion = XML::Node.new(self.class.to_s)
    node_opinion['dimension'] = feature_rating_idurl if feature_rating_idurl
    #node_opinion['review_id'] = review_id.to_s
    #node_opinion['paragraph_id'] = paragraph_id.to_s
    node_opinion
  end

  def value_oriented_html() "<b>&nbsp;$</b>" if value_oriented end


  def self.product_ids_origin(knowledge, review)
    l_select = review.products.collect { |p| [p.label, p.id] }
    header = []
    header << [l_select.collect(&:first).join(' & '), l_select.collect(&:last).join('-')] if l_select.size > 1

    knowledge.products.each do |p|
      l_select << [p.label, p.id] unless l_select.any? { |l,i| i == p.id }  
    end
    header.concat(l_select)
    header
  end

end


class Rating < Opinion


  key :min_rating, Float, :default => 1
  key :max_rating, Float, :default => 5
  key :rating, Float, :default => 3

  def is_valid?() min_rating and max_rating and rating end

  def to_html(options={}) "#{rating} in [#{min_rating}, #{max_rating}] (#{feature_rating_idurl}#{value_oriented_html})" end

  def rating_01() Root.rule3(rating, min_rating, max_rating) end

  def is_rating?() true end

  def to_xml_bis
    node_opinion = super
    node_opinion['rating'] = rating.to_s
    node_opinion['min'] = min_rating.to_s
    node_opinion['max'] = max_rating.to_s
    node_opinion
  end

end

class Comparator < Opinion

  key :operator_type, String
  key :predicate, String

  def to_html(options={}) "#{operator_type} than #{predicate} (#{feature_rating_idurl}#{value_oriented_html})" end

  def is_valid?() ["best", "worse", "same"].include?(operator_type) and !Root.is_empty(predicate)  end

  def self.create_from_xml(feature_idurl, operator_type, xml_node)
    self.create(:feature_idurl => feature_idurl,
                               :operator_type => operator_type,
                               :predicate => xml_node["predicate"],
                               :label => xml_node.content.strip)
  end

  def to_xml_bis
    node_opinion = super
    node_opinion['operator'] = operator_type
    node_opinion['predicate'] = predicate
    node_opinion
  end

end


class Tip < Opinion

  key :intensity_symbol, String

  def to_html(options={})
    s = "#{intensity_as_label} (#{feature_rating_idurl}#{value_oriented_html})"
    if options[:origin]
      p = paragraph
      s << "&nbsp;<small><a href=\"/reviews/show/#{review.id}?opinion_id=#{self.id}\" >#{review.source}"
      s << "</a></small>"
    end
    s
  end

  def to_xml_bis
    node_opinion = super
    node_opinion['value'] = intensity_symbol
    node_opinion << usage
    node_opinion
  end

  def is_valid?() !Root.is_empty(usage) and !Root.is_empty(intensity) end

  def self.intensities_symbols
    [ ["very high", "very_high" ],
      ["high", "high"],
      ["neutral", "neutral"],
      ["low", "low"],
      ["very low", "very_low" ],
      ["mixed", "mixed"] ]
  end

  def self.intensities_value
    { "very_high" => 1.0, "high" => 0.5, "neutral" => 0.0, "mixed" => 0.0, "low" => -0.5, "very_low" => -1.0 }
  end

  def intensity_as_label() x = Tip.intensities_symbols.detect { |l,k| k == intensity_symbol }; x ? x.first : "?????" end

  def intensity()
    x = Tip.intensities_value[intensity_symbol]
    puts "********** intensity #{x} for symbol #{intensity_symbol}"
    x
  end

  def is_mixed() intensity_symbol == "mixed" end
  
end


class FeatureRelated < Opinion

  key :feature_related_idurl, String

  def to_html(options={}) "related to feature #{feature_related_idurl}" end

  def is_valid?() true end

  def to_xml_bis
    node_opinion = super
    node_opinion['feature_idurl'] = feature_related_idurl
    node_opinion
  end

end

