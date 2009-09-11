require 'pkz_xml.rb'
require 'pkz_authored.rb'


module Pikizi

class Product < Root

  attr_accessor :modeldatas # hash table base on knowledge_key

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.modeldatas = Root.get_hash_from_xml(xml_node, 'modeldata', 'key') { |node_modeldata| Modeldata.create_from_xml(node_modeldata) }
  end

  # generate xml according to knowledge structure...
  def generate_xml(top_node, knowledge_keys)
    puts "*** generating product=#{key}"
    node_product = super(top_node)
    knowledge_keys.each { |knowledge_key| modeldatas[knowledge_key].generate_xml(node_product, Knowledge.get_from_cache(knowledge_key)) } if modeldatas
    node_product
  end

  def to_xml(knowledge_keys, key=nil)
    super(key, knowledge_keys)
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
    super(XML::Document.file(self.filename_data(product_key)).root)
  end


  # get the values for a feature
  def get_values(knowledge_key, feature_key) get_data(knowledge_key, feature_key, "values") end

  # set/get the background for a feature
  def get_background(knowledge_key, feature_key, background_key) get_data(knowledge_key, feature_key, "hash_key_background", background_key) end
  def get_backgrounds(knowledge_key, feature_key) get_data(knowledge_key, feature_key, "hash_key_background", nil) end

  # set/get the opinion for a feature
  # if already existing average weighted...
  def set_opinion(auth_opinion, user, knowledge_key, feature_key) set_data(user, knowledge_key, feature_key, "hash_key_opinion", auth_opinion, auth_opinion.key) end
  def get_opinion(knowledge_key, feature_key, opinion_key) get_data(knowledge_key, feature_key, "hash_key_opinion", opinion_key) end
  def get_opinions(knowledge_key, feature_key) get_data(knowledge_key, feature_key, "hash_key_opinion", nil) end


       
  private


  def get_data(knowledge_key, feature_key, method, hash_key=nil)
    fd = feature_data(knowledge_key, feature_key)
    hash_key ? fd.send(method)[hash_key] : fd.send(method)
  end

  def feature_data(knowledge_key, feature_key)
    feature_key ||= model_key
    modeldata = (modeldatas[knowledge_key] ||= Modeldata.create_with_parameters(knowledge_key))
    modeldata.featuredatas[feature_key] ||= Featuredata.create_with_parameters(feature_key)
  end


end


# describe a set of values for a given model
# the key is the model key
class Modeldata < Root
    
  attr_accessor :featuredatas # hash by key
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    self.featuredatas = Root.get_hash_from_xml(xml_node, "//featuredata", 'key') { |node_featuredata| Featuredata.create_from_xml(node_featuredata) }
    
  end
  
  def generate_xml(top_node, knowledge)
    node_modeldata = super(top_node)
    generate_xml_bis(knowledge, node_modeldata)
    node_modeldata
  end

  def generate_xml_bis(feature, node_feature)

    node_feature << XML::Node.new_comment(feature.label)

    # this generate the xml, background and opinion

    if featuredata = featuredatas[feature.key]
      featuredata.generate_xml(feature, node_feature, featuredatas)
    else
      node_feature << (node_featuredata = XML::Node.new('featuredata'))
      node_featuredata['feature_key'] = feature.key
      feature.generate_xml_4_value(node_featuredata, featuredatas)
    end

    if feature.sub_features and feature.sub_features.size > 0
      node_feature << (node_sub_features = XML::Node.new('sub_features'))
      feature.sub_features.each { |sf| generate_xml_bis(sf, node_sub_features) }
    end
    node_feature
  end

  def self.create_with_parameters(knowledge_key)
    modeldata = super(knowledge_key)
    modeldata.featuredatas = {}
    modeldata
  end

end

# describe a set of Data for a given feature in a given model and a product
class Featuredata < Root

  attr_accessor :values, :hash_key_background, :hash_key_opinion
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    #self.value = ((node_value = xml_node.find_first('value')) ? Value.create_from_xml(node_value) : nil)
    self.values = Root.get_collection_from_xml(xml_node, "value") { |node_value| node_value.content.strip }
    self.hash_key_background = Root.get_hash_from_xml(xml_node, "background", "key") { |node_background| Background.create_from_xml(node_background) }
    self.hash_key_opinion = Root.get_hash_from_xml(xml_node, "opinion", "key") { |node_opinion| Opinion.create_from_xml(node_opinion) }
  end

  
  def generate_xml(feature, top_node, featuredatas)
    node_featuredata = super(top_node)
    feature.generate_xml_4_value(node_featuredata, featuredatas)
    hash_key_background.each { |background_key, background| background.generate_xml(node_featuredata) }
    hash_key_opinion.each { |opinion_key, opinion| opinion.generate_xml(node_featuredata) }
    node_featuredata
  end

  
  def self.create_with_parameters(feature_key)
    featuredata = super(feature_key)
    featuredata.values = []
    featuredata.hash_key_background = {}
    featuredata.hash_key_opinion = {}
    featuredata
  end

end





end
