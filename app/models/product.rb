require 'xml'
require 'mongo_mapper'
require 'amazon'

class Product < Root

  include MongoMapper::Document

  key :idurl, String, :index => true # unique url

  key :label, String # unique url
  key :knowledge_idurl, String

  # no backgrounds (handled by feature...)
  
  key :hash_feature_idurl_value, Hash

  timestamps!

  def self.is_main_document() true end

  def get_knowledge() @knowledge ||= Knowledge.load(knowledge_idurl) end
  
  def get_value(feature_idurl) hash_feature_idurl_value[feature_idurl] end

  def set_value(feature_idurl, value) hash_feature_idurl_value[feature_idurl] = value end

  # return the amazon_id for request
  def get_amazon_id
    if amazon_url = get_value("amazon_url")
      amazon_url = amazon_url.remove_prefix("http://www.amazon.com/gp/product/")
      amazon_url[0, 10] if amazon_url
    end    
  end

  def create_amazon_reviews(knowledge)
    xml_filename = "amazon.xml"
    #Review.delete_all(:filename => xml_filename)
    #Review.find(:all, :filename => xml_filename, :product_idurl => idurl).each(&:destroy)
    Review.delete_all(:filename => xml_filename, :product_idurl => idurl)
    begin
      ApiAmazon.get_amazon_reviews(get_amazon_id, 1, 10).each do |amazon_review|
        puts "#{idurl}=#{amazon_review.inspect}"
        Review::Rating.create(:filename => xml_filename,
                              :knowledge_idurl => knowledge.idurl,
                              :product_idurl => idurl,
                              :author_email => "amazon_customer_#{amazon_review[:customerid]}",
                              :source => "Amazon",
                              :source_url => get_value("amazon_url"),
                              :written_at => DateTime.parse(amazon_review[:date]),
                              :feature_idurl => "overall_rating",
                              :label => amazon_review[:summary],
                              :label_full => amazon_review[:content],
                              :reputation => Float(amazon_review[:totalvotes]),
                              :min_rating => 1,
                              :max_rating => 5,
                              :rating => Float(amazon_review[:rating]) )
        puts "#{idurl} created"
      end
    rescue Exception => e
      puts "Oups extractring reviews for product #{idurl} #{e.message}"
    end
  end

  def gallery_image_urls
    path = "/domains/#{knowledge_idurl}/products/#{idurl}/gallery"
    Root.get_entries("public/#{path}").collect { |entry| "#{path}/#{entry}"}.first(3)
  end
  
  def self.initialize_from_xml(knowledge, xml_node)
    product = super(xml_node)
    product.hash_feature_idurl_value = {}
    product.knowledge_idurl = knowledge.idurl
    xml_node.find("Value").each do |node_value|
      feature_idurl = node_value['idurl']
      if feature = knowledge.get_feature_by_idurl(feature_idurl)
        node_value_content = node_value.content.strip
        begin
          value = feature.xml2value(node_value_content)
        rescue
          value = nil
          if node_value_content == ""
            #puts "EMPTY value product=#{product.idurl} feature=#{feature.idurl}"  unless feature.is_optional
          else
            puts "ERROR value product=#{product.idurl} feature=#{feature.idurl} xml_value=#{node_value_content.inspect}"
          end
        end
        product.set_value(feature_idurl, value)
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
