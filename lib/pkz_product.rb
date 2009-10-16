require 'pkz_xml.rb'


module Pikizi

class Product < Root

  attr_accessor :knowledgedatas # hash table base on knowledge_key

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledgedatas = Root.get_hash_from_xml(xml_node, 'knowledgedata', 'key') { |node_knowledgedata| Knowledgedata.create_from_xml(node_knowledgedata) }
  end

  # generate xml according to knowledges structure...
  def generate_xml(top_node)
    node_product = super(top_node)
    knowledgedatas.each do |knowledge_key, knowledgedata| knowledgedata.generate_xml(node_product, Knowledge.get_from_cache(knowledge_key)) end
    node_product
  end


  def self.get_from_cache(product_key, reload=nil)
    @hash ||= {}
    @hash[product_key] ||= Rails.cache.fetch("P#{product_key}", :force => reload) { Product.create_from_xml(product_key) }  
  end



  # load an xml file... and retutn a Product object  
  def self.create_from_xml(product_key)
    raise "Error product doesn't exist" unless key_exist?(product_key)
    PK_LOGGER.info "loading XML product #{product_key} from filesystem"
    super(XML::Document.file(self.filename_data(product_key)).root)
  end

  # get the values for a feature
  def get_values(knowledge_key, feature_key) get_data(knowledge_key, feature_key, "values") end

  # set/get the background for a feature
  def get_background(knowledge_key, feature_key, background_key) get_data(knowledge_key, feature_key, "hash_key_background", background_key) end
  def get_backgrounds(knowledge_key, feature_key) get_data(knowledge_key, feature_key, "hash_key_background", nil) end
  

  def feature_data(knowledge_key, feature_key)
    feature_key ||= model_key
    knowledgedata = (knowledgedatas[knowledge_key] ||= Knowledgedata.create_with_parameters(knowledge_key))
    knowledgedata.featuredatas[feature_key] ||= Featuredata.create_with_parameters(feature_key)
  end


  private


  def get_data(knowledge_key, feature_key, method, hash_key=nil)
    fd = feature_data(knowledge_key, feature_key)
    hash_key ? fd.send(method)[hash_key] : fd.send(method)
  end


end


# describe a set of values for a given model
# the key is the model key
class Knowledgedata < Root
    
  attr_accessor :featuredatas # hash by key
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    self.featuredatas = Root.get_hash_from_xml(xml_node, "//featuredata", 'key') { |node_featuredata| Featuredata.create_from_xml(node_featuredata) }
    
  end
  
  def generate_xml(top_node, knowledge)
    node_knowledgedata = super(top_node)
    generate_xml_bis(knowledge, node_knowledgedata)
    node_knowledgedata
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
    knowledgedata = super(knowledge_key)
    knowledgedata.featuredatas = {}
    knowledgedata
  end

end

# describe a set of Data for a given feature in a given model and a product
class Featuredata < Root

  attr_accessor :values, :hash_key_background
  
  def initialize_from_xml(xml_node)
    super(xml_node)
    self.values = Root.get_collection_from_xml(xml_node, "value") { |node_value| node_value.content.strip }
    self.hash_key_background = Root.get_hash_from_xml(xml_node, "background", "key") { |node_background| Background.create_from_xml(node_background) }
  end

  
  def generate_xml(feature, top_node, featuredatas)
    node_featuredata = super(top_node)
    feature.generate_xml_4_value(node_featuredata, featuredatas)
    hash_key_background.each { |background_key, background| background.generate_xml(node_featuredata) }
    node_featuredata
  end

  
  def self.create_with_parameters(feature_key)
    featuredata = super(feature_key)
    featuredata.values = []
    featuredata.hash_key_background = {}
    featuredata
  end

end






end
