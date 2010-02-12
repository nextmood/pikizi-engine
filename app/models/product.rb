require 'xml'
require 'mongo_mapper'
require 'amazon'
require 'review'

class Product < Root

  include MongoMapper::Document

  key :idurl, String, :index => true # unique url

  key :label, String # unique url
  key :knowledge_idurl, String

  # no backgrounds (handled by feature...)
  
  key :hash_feature_idurl_value, Hash

  timestamps!

  def reviews() Review.find(:all, :product_idurl => idurl) end

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

  AMAZON_SOURCE = "Amazon"
  def create_amazon_reviews(knowledge)
    Review.delete_with_opinions(:product_idurl => idurl, :source => Review::FromAmazon.source_default) # also destroy the attached opinions

    begin
      nb_reviews_imported = 0
      ApiAmazon.get_amazon_reviews(get_amazon_id, 1, 10).each do |amazon_review|
        Review::FromAmazon.create_with_opinions(knowledge, idurl, get_value("amazon_url"), amazon_review)
        nb_reviews_imported += 1
      end
      puts "#{'* ' if nb_reviews_imported == 0} #{idurl}=#{nb_reviews_imported} reviews imported"
    rescue Exception => e
      puts "*** #{idurl} (reviews=#{nb_reviews_imported}) #{e.message}"
    end
  end

  # return a hash
  # h[feature_idurl][category][:weighted_avg_01]
  # h[feature_idurl][category][:review_ids]
  #
  def get_ratings_group_by_feature_and_category

    hash_fidurl_category_opinions = {}
    Review.find(:all, :product_idurl => idurl).each do |review|
      review.opinions.each do |opinion|
        puts "opinion class=#{opinion.class}"
        if opinion.is_rating?
          puts "opinion rating"
          tupple = [opinion, review]
          ((hash_fidurl_category_opinions[opinion.feature_idurl] ||= {})[review.get_category] ||= []) <<  tupple
        end
      end
    end


    # compute the average rating for each category
    hash_fidurl_category_opinions.each do |feature_idurl, hash_category_opinions|

      # Begin for a given feature
      hash_category_opinions.each do |category, opinions_reviews|

        # Begin for a given category
        sum_reputation = 0.0; sum_weighted = 0.0; reviews = []

        opinions_reviews.each do |opinion, review|
          review.reputation ||= 1.0
          sum_reputation += review.reputation
          sum_weighted += review.reputation * opinion.rating_01
          reviews << review unless reviews.include?(review) 
        end

        hash_category_opinions[category] = { :weighted_avg_01 => sum_weighted / sum_reputation, :reviews => reviews } if sum_reputation > 0.0

        # End for a given feature

      end
      # End for a given feature

    end
    puts "hash_fidurl_category_opinions=#{hash_fidurl_category_opinions.inspect}"
    hash_fidurl_category_opinions  
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
