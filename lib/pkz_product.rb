require 'pkz_xml.rb'
require 'pkz_authored.rb'

module Pikizi

class Product < Root

  attr_accessor :modeldatas # hash table base on knowledge_key

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.modeldatas = Root.get_hash_from_xml(xml_node, 'modeldata', 'key') { |node_modeldata| Modeldata.create_from_xml(node_modeldata) }
  end
  
  def generate_xml(top_node)
    node_product = super(top_node)
    modeldatas.each { |key, modeldata| modeldata.generate_xml(node_product) } if modeldatas
    node_product
  end

  def self.get_from_cache(product_key, reload=nil)
    Rails.cache.fetch("P#{product_key}", :force => reload) { Product.create_from_xml(product_key) }  
  end

  # load an xml file... and retutn a Product object  
  def self.create_from_xml(product_key)
    unless key_exist?(product_key)
      pkz_product = Pikizi::Product.new
      pkz_product.key = product_key
      pkz_product.label = "Label for #{product_key}"
      pkz_product.save
      PK_LOGGER.info "XML product #{product_key} created on filesystem"              
    end
    PK_LOGGER.info "loading XML product #{product_key} from filesystem"
    super(XML::Document.file(filename_data(product_key)).root)
  end


  # set/get the value for a feature
  # if already existing keep the one from the user with the best reputation (if different !)
  def set_value(auth_value, user, knowledge_key, feature_key) set_data(user, knowledge_key, feature_key, "value", auth_value) end
  def get_value(knowledge_key, feature_key) avg_value(get_data(knowledge_key, feature_key, "value")) end

  # set/get the background for a feature
  # if already existing keep the one from the user with the best reputation (if different !)
  def set_background(auth_background, user, knowledge_key, feature_key) set_data(user, knowledge_key, feature_key, "hash_key_background", auth_background, auth_background.key) end
  def get_background(knowledge_key, feature_key, background_key) avg_value(get_data(knowledge_key, feature_key, "hash_key_background", background_key)) end
  def get_backgrounds(knowledge_key, feature_key) avg_value(get_data(knowledge_key, feature_key, "hash_key_background", nil)) end

  # set/get the opinion for a feature
  # if already existing average weighted...
  def set_opinion(auth_opinion, user, knowledge_key, feature_key) set_data(user, knowledge_key, feature_key, "hash_key_opinion", auth_opinion, auth_opinion.key) end
  def get_opinion(knowledge_key, feature_key, opinion_key) avg_value(get_data(knowledge_key, feature_key, "hash_key_opinion", opinion_key)) end
  def get_opinions(knowledge_key, feature_key) avg_value(get_data(knowledge_key, feature_key, "hash_key_opinion", nil)) end


       
  private


  def set_data(user, knowledge_key, feature_key, method, atom, hash_key=nil)
    if existing_atom = get_data(knowledge_key, feature_key, method, hash_key)
      new_atom = existing_atom.add_auth(user, atom)
    else
      atom.aggregation = atom.get_aggregation_instance
      new_atom = atom.add_auth(user, atom)
    end
    fd = feature_data(knowledge_key, feature_key)
    hash_key ? fd.send(method)[hash_key] = new_atom : fd.send("#{method}=", new_atom)
  end

  def get_data(knowledge_key, feature_key, method, hash_key=nil)
    fd = feature_data(knowledge_key, feature_key)
    hash_key ? fd.send(method)[hash_key] : fd.send(method)
  end

  def feature_data(knowledge_key, feature_key)
    feature_key ||= model_key
    modeldata = (modeldatas[knowledge_key] ||= Modeldata.create_with_parameters(knowledge_key))
    modeldata.featuredatas[feature_key] ||= Featuredata.create_with_parameters(feature_key)
  end

  def avg_value(x)
    (x.is_a?(Hash) ? x.inject({}) { |h, (k,v)| h[k] = avg_value(v); h } : x.value ) if x
  end

end


# describe a set of values for a given model
# the key is the model key
class Modeldata < Root
    
  attr_accessor :featuredatas # hash by key
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    self.featuredatas = Root.get_hash_from_xml(xml_node, "featuredata", 'key') { |node_featuredata| Featuredata.create_from_xml(node_featuredata) }
  end
  
  def generate_xml(top_node)
    node_modeldata = super(top_node)
    featuredatas.each { |key, featuredata| featuredata.generate_xml(node_modeldata) }
    node_modeldata
  end
    
  def self.create_with_parameters(knowledge_key)
    modeldata = super(knowledge_key)
    modeldata.featuredatas = {}
    modeldata
  end

end

# describe a set of Aggregation for a given feature in a given model
class Featuredata < Root
    
  attr_accessor :value, :hash_key_background, :hash_key_opinion
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    self.value = ((node_value = xml_node.find_first('value')) ? Value.create_from_xml(node_value) : nil)
    self.hash_key_background = Root.get_hash_from_xml(xml_node, "background", "key") { |node_background| Background.create_from_xml(node_background) }
    self.hash_key_opinion = Root.get_hash_from_xml(xml_node, "opinion", "key") { |node_opinion| Opinion.create_from_xml(node_opinion) }
  end

  
  def generate_xml(top_node)
    node_featuredata = super(top_node)
    value.generate_xml(node_featuredata) if value
    hash_key_background.each { |background_key, background| background.generate_xml(node_featuredata) }
    hash_key_opinion.each { |opinion_key, opinion| opinion.generate_xml(node_featuredata) }
    node_featuredata
  end

  def self.create_with_parameters(feature_key)
    featuredata = super(feature_key)
    featuredata.value = nil
    featuredata.hash_key_background = {}
    featuredata.hash_key_opinion = {}
    featuredata
  end

end





end
