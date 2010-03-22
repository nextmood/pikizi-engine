require 'mongo_mapper'

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Opinion < Root
  
  include MongoMapper::Document


  key :feature_rating_idurl, String # the reference to a feature rating in the model   (rating dimension)
  key :label, String # summary of the opinion
  key :_type, String # class management
  key :usage, String
  
  key :review_id, Mongo::ObjectID # the review where this opinion was extracted
  belongs_to :review

  key :user_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :user

  key :paragraph_id, Mongo::ObjectID # from which paragraph (if any) this opinion was extracted
  belongs_to :paragraph
  
  timestamps!



  def self.is_main_document() true end

  def to_html(options={}) "feature_rating_idurl=#{feature_rating_idurl} label=#{label}, class=#{_type} paragraph_ranking_number=#{paragraph.ranking_number}" end


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

end


class Rating < Opinion


  key :min_rating, Float
  key :max_rating, Float
  key :rating, Float

  def is_valid?() min_rating and max_rating and rating end

  def to_html(options={}) "#{rating} in [#{min_rating}, #{max_rating}] (#{feature_rating_idurl})" end

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

  def to_html(options={}) "#{operator_type} than #{predicate} #{usage} (#{feature_rating_idurl})" end

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

  key :intensity, Float
  key :is_mixed, Boolean, :default => false
  
  def to_html(options={})
    if is_mixed
      s = "mixed : #{usage} (#{feature_rating_idurl})"
    else
      intensity_symbol = Tip.intensities.detect { |i| intensity == i.last }
      intensity_symbol = intensity_symbol ? intensity_symbol.first  : intensity
      s = "#{intensity_symbol} : #{usage} (#{feature_rating_idurl})"

    end
    if options[:origin]
      p = paragraph
      s << "&nbsp;<small><a href=\"/reviews/show/#{review.id}?p=#{paragraph.ranking_number}\" >#{review.source}"
      s << "&nbsp;&para;#{paragraph.ranking_number}" if p
      s << "</a></small>"
    end

    s
  end

  def to_xml_bis
    node_opinion = super
    node_opinion['value'] = intensity_as_string
    node_opinion << usage
    node_opinion
  end

  def is_valid?() !Root.is_empty(usage) and !Root.is_empty(intensity) end

  def intensity_as_string
    if is_mixed
      "mixed"
    else
      intensity_symbol = Tip.intensities.detect { |i| intensity == i.last }
      intensity_symbol ? intensity_symbol.first  : intensity
    end  
  end

  def self.intensities
    [ ["very_high", 1.0 ],
      ["high", 0.5],
      ["neutral", 0.0],
      ["low", -0.5],
      ["very_low", -1.0 ],
      ["mixed", "mixed"] ]
  end
  
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

