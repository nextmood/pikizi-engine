require 'xml'
require 'mongo_mapper'

class Product < Root

  include MongoMapper::Document

  key :idurl, String, :index => true # unique url

  key :label, String # unique url

  # no backgrounds (handled by feature...)
  
  key :hash_feature_idurl_value, Hash

  timestamps!

  def self.is_main_document() true end

  
  attr_accessor :knowledge

  def link_back(knowledge)
    self.knowledge = knowledge
  end

  def get_value(feature_idurl)
    x = hash_feature_idurl_value[feature_idurl]
    # puts "getting feature=#{feature_idurl} for product=#{idurl} --> #{x.inspect}"
    x
  end

  def self.initialize_from_xml(knowledge, xml_node)
    product = super(xml_node)
    product.hash_feature_idurl_value = {}
    xml_node.find("Value").each do |node_value|
      feature_idurl = node_value['idurl']
      if feature = knowledge.get_feature_by_idurl(feature_idurl)
        node_value_content = node_value.content.strip
        begin
          value = feature.xml2value(node_value_content)
        rescue
          value = nil
          if node_value_content == ""
            puts "EMPTY value product=#{product.idurl} feature=#{feature.idurl}"  unless feature.is_optional
          else
            puts "ERROR value product=#{product.idurl} feature=#{feature.idurl} xml_value=#{node_value_content.inspect}"
          end
        end
        product.hash_feature_idurl_value[feature_idurl] = value
      else
        puts "**** feature #{feature_idurl} in product #{product.idurl} doesn't exist in knowledge"  
      end
    end
    product.save
    product
  end


  def generate_xml(knowledge, top_node)
    node_product = super(top_node)
    knowledge.each_feature do |feature|
      feature_idurl = feature.idurl
      if value = get_value(feature_idurl)
        node_value = XML::Node.new("Value")
        node_value['idurl'] = feature_idurl
        node_value << feature.value2xml(value)
        node_product << node_value
      end
    end
    node_product
  end


end
