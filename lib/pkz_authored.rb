require 'pkz_xml.rb'

module Pikizi

require 'xml'

# ---------------------------------------------------------------------------------------------
# Kind of Value

class Atomic < Root

  attr_accessor :knowledge_key, :feature_key, :product_key, :timestamp, :aggregation

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledge_key = xml_node['knowledge_key']
    self.feature_key = xml_node['feature_key']
    self.product_key = xml_node['product_key']
    self.timestamp =  Time.parse(xml_node['timestamp'])
    node_aggregation = xml_node.find_first("aggregation")
    self.aggregation = node_aggregation ? Aggregation.create_from_xml(node_aggregation) : nil
  end

  def generate_xml(top_node, class_name)
    node_atomic = super(top_node, class_name)
    node_atomic['knowledge_key'] = knowledge_key
    node_atomic['feature_key'] = feature_key
    node_atomic['product_key'] = product_key
    node_atomic['timestamp'] = timestamp.strftime(Root.default_date_format)
    aggregation.generate_xml(node_atomic) if aggregation
    node_atomic
  end

  # return the new atom
  def add_auth(user, new_atom)
    aggregated_atom = (aggregation.add_auth(user, new_atom) || self)
    aggregated_atom.aggregation = aggregation
    aggregated_atom
  end


end

# describe a rating on a feature
class Opinion < Atomic

  attr_accessor :type_opinion, :max_rating, :min_rating, :value_rating

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.type_opinion = xml_node['type']
    self.min_rating = Float(xml_node['min_rating'])
    self.max_rating = Float(xml_node['max_rating'])
    self.value_rating = Float(xml_node['value'])    
  end

  def generate_xml(top_node)
    node_opinion = super(top_node, 'opinion')
    node_opinion['min_rating'] = min_rating.to_s
    node_opinion['max_rating'] = max_rating.to_s
    node_opinion['value'] = value_rating.to_s
    node_opinion
  end

  def value() value_rating / (max_rating - min_rating)  end

  def self.create_new_instance_from_xml(xml_node)
   Pikizi.const_get(xml_node['type'].capitalize).new
  end

  def get_aggregation_instance() AggregationAverageWeighted.create_with_parameters(key) end



end

class Rating < Opinion

  attr_accessor :user_category

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.user_category = xml_node['user_category']
  end

  def generate_xml(top_node)
    node_opinion = super(top_node)
    node_opinion['type'] = 'rating'
    node_opinion['user_category'] = user_category
    node_opinion
  end

end

# describe a Value for a given feature
class Value < Atomic

  attr_accessor :value

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.value = xml_node.content.strip
  end

  def generate_xml(top_node)
    node_atom_value = super(top_node, nil)
    node_atom_value << value
    node_atom_value
  end

  def get_aggregation_instance() AggregationBest.create_with_parameters(key) end

end


# describe a background for a given feature  abstract class
class Background < Atomic

  attr_accessor :value

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.value = xml_node.content
  end

  def generate_xml(top_node)
    node_background = super(top_node, "background")
    type_bgk = self.class.to_s.downcase; type_bgk.slice!("pikizi::background")
    node_background['type'] = type_bgk
    node_background << value
    node_background
  end

  def self.create_new_instance_from_xml(xml_node)
    Pikizi.const_get("Background#{xml_node['type'].capitalize}").new
  end

  def get_aggregation_instance() AggregationBest.create_with_parameters(key) end  

end

class BackgroundText < Background
end

class BackgroundHtml < Background
end

# content is a Url
class BackgroundUrl < Background
end

class BackgroundImage < BackgroundUrl
end

class BackgroundVideo < BackgroundUrl
end


# ---------------------------------------------------------------------------------------------
# Aggregation Classes

# describe an aggregation (average) of an authored object, value, background or opinion for a feature,
# the key of an aggregation is the  class of authored
class Aggregation < Root

  attr_accessor :author_keys

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.author_keys = Root.get_collection_from_xml(xml_node, "author") { |node_user_key| node_user_key['key'] }
  end

  def generate_xml(top_node)
    node_aggregation = super(top_node, "aggregation")
    author_keys.each { |author_key| node_aggregation << (node_author = XML::Node.new('author')); node_author['key'] = author_key }
    type_aggregation = self.class.to_s;  type_aggregation.slice!("Pikizi::Aggregation")
    node_aggregation['type'] = type_aggregation
    node_aggregation
  end

  def self.create_with_parameters(key)
    aggregation = super(key)
    aggregation.author_keys = []
    aggregation
  end

  def self.create_new_instance_from_xml(xml_node)
   Pikizi.const_get("Aggregation#{xml_node['type']}").new
  end

  def add_auth(user)
    author_keys << user.key unless author_keys.include?(user.key)
  end

end

class AggregationBest < Aggregation

  attr_accessor :best_user_reputation, :best_timestamp, :best_user_key

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.best_user_reputation = Float(xml_node['best_user_reputation'])
    self.best_timestamp =  Time.parse(xml_node['best_timestamp'])
    self.best_user_key = xml_node['best_user_key']
  end

  def generate_xml(top_node)  
    node_aggregation_best = super(top_node)
    node_aggregation_best['best_user_reputation'] = best_user_reputation.to_s
    node_aggregation_best['best_timestamp'] = best_timestamp ? best_timestamp.strftime(Root.default_date_format) : ""
    node_aggregation_best['best_user_key'] = best_user_key.to_s
    node_aggregation_best
  end

  def self.create_with_parameters(key)
    aggregation_best = super(key)
    aggregation_best.best_user_reputation = nil
    aggregation_best.best_timestamp =  nil
    aggregation_best.best_user_key = nil
    aggregation_best
  end

  def is_best(user) best_user_reputation.nil? or user.reputation > best_user_reputation end

  # return the new atom if it's better'
  def add_auth(user, new_atom)
    super(user)
    if is_best(user)
      self.best_user_key = user.key
      self.best_user_reputation = user.reputation
      self.best_timestamp =  new_atom.timestamp
      new_atom
    end
  end



end

class AggregationAverageWeighted < Aggregation

  attr_accessor :nb_weighted, :sum_weighted

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.nb_weighted = Float(xml_node['nb_weighted'] || 0.0)
    self.sum_weighted = Float(xml_node['sum_weighted'] || 0.0)
  end

  def self.create_with_parameters(key)
    aggregation_average_weighted = super(key)
    aggregation_average_weighted.nb_weighted = 0.0
    aggregation_average_weighted.sum_weighted = 0.0
    aggregation_average_weighted
  end

  def generate_xml(top_node)
    node_aggregation_average_weighted = super(top_node)
    node_aggregation_average_weighted['nb_weighted'] = nb_weighted.to_s
    node_aggregation_average_weighted['sum_weighted'] = sum_weighted.to_s
    node_aggregation_average_weighted
  end

  # return a new average value atom
  def add_auth(user, new_atom)
    super(user)
    self.nb_weighted += user.reputation
    self.sum_weighted +=  (new_atom.value * user.reputation)
    new_atom.min_rating = 0.0
    new_atom.max_rating = 1.0
    new_atom.value_rating = sum_weighted / nb_weighted
    new_atom
  end


end

 

end
