require 'xml'
require 'mongo_mapper'
require 'amazon'
require 'review'

class Product < Root

  include MongoMapper::Document

  key :idurl, String # unique url

  key :knowledge_idurl, String
  key :knowledge_id, BSON::ObjectID
  belongs_to :knowledge # described by only one knowledge/model (i thought a lot about that) 

  # header of all products / whatever the model/knowledge associated
  key :label, String # unique url
  key :category, String # a sub categorization of product  (exemple camera phone)
  key :release_date, Date # date when this product is on the market
  key :overall_rating, Float
  key :image_urls, Array #an array of images url

  key :image_ids, Array # an array of Media ids
  key :description_id, Media # a media id





  key :url, String
  
  key :description_urls, Array # an array of description url?

  #many :reviews
  def reviews() Review.all(:product_ids => self.id, :order => "written_at DESC") end
  def reviews_count(options={}) options[:product_ids] = self.id; Review.count(options) end
  def review_last(options={})
    options[:product_ids] = self.id
    options[:order] = "written_at DESC"
    Review.first(options) 
  end

  # offers holds, price and merchants for this product
  def offers() Offer.all(:product_ids => self.id) end
  def offer_count() Offer.count(:product_ids => self.id) end

  # opinions
  def opinions(options={})
    except_review_categories = options[:except_review_category]
    except_review_categories = [except_review_categories] unless except_review_categories.nil? or except_review_categories.is_a?(Array)
    Opinion.all(:product_ids => self.id).select do |o|
      except_review_categories ? !except_review_categories.include?(o.review.category) : true  
    end
  end

  # ordered list from the most similar to the less similar
  key :similar_product_ids, Array, :default => []
  def similar_products() Product.find(similar_product_ids) end
  
  # cache/explnantion
  key :explanation_rating, Hash, :default => {}
  key :search_data, String # compilation of brand, price, catageory for search speed (this is a cache)

  timestamps!

  @@product_collection_html = {}
  def self.product_collection_html(knowledge_id, options={})
    if @@product_collection_html[knowledge_id].nil? or options[:reset]
      @@product_collection_html[knowledge_id] = Product.all(:knowledge_id => knowledge_id).collect {|p| [p.label, p.id]}.sort {|x,y| x.first.downcase <=> y.first.downcase }
    end
    @@product_collection_html[knowledge_id]
  end

  def product_collection_html
    exclude_ids = ((self.similar_product_ids || []) << id)
    (l = Product.product_collection_html(knowledge_id)).delete_if { |label, id | exclude_ids.include?(id) }
    l
  end

  # return a list of products similar
  def self.similar_to(input, reset=nil)
    input = input.downcase
    @@product_labels = nil if reset
    @@product_labels ||= Product.all(:order => "label").collect(&:label)
    @@product_labels.select { |l| l.downcase.index(input) }
  end



  def add_similar_product(similar_product)
    add_similar_product_bis(similar_product)
    similar_product.add_similar_product_bis(self)
  end

  def add_similar_product_bis(similar_product)
    self.similar_product_ids ||= []
    unless similar_product_ids.include?(similar_product.id)
      self.similar_product_ids << similar_product.id
      save
    end
  end

  def delete_similar_product(similar_product)
    delete_similar_product_bis(similar_product)
    similar_product.delete_similar_product_bis(self)
  end

  def delete_similar_product_bis(similar_product)
    self.similar_product_ids ||= []
    if similar_product_ids.include?(similar_product.id)
      self.similar_product_ids.delete(similar_product.id)
      save
    end
  end


  def fillup_image_ids
    knowledge_idurl = knowledge.idurl
    path = "public/domains/#{knowledge_idurl}/products/#{idurl}/images"
    entries = Root.get_entries(path).collect { |entry| "#{path}/#{entry}"}
    path = "public/domains/#{knowledge_idurl}/products/#{idurl}/gallery"
    entries.concat(Root.get_entries(path).collect { |entry| "#{path}/#{entry}"})
    self.image_ids = []
    entries.each do |entry|
      if Media::MediaImage.extension_valid?(entry)
        media_ids = Media::MediaImage.create_from_path(entry)
        self.image_ids << media_ids
      else
        puts "unknown extension for pidurl=#{idurl} entry #{entry}"
      end
    end
    save
    true
  end

  def fillup_others
    knowledge_idurl = knowledge.idurl
    begin
      path = "public/domains/#{knowledge_idurl}/products/#{idurl}/content"
      if (entries = Root.get_entries(path).collect { |entry| "#{path}/#{entry}"}).first
        self.description_id = Media.grid.put(File.new(entries.first).read, entries.first, :content_type => "text/html")
      end
    rescue
      puts "oups with description for product=#{idurl}"
    end
    feature_url = knowledge.get_feature_by_idurl('main_url')
    self.url = feature_url.get_value(self)
    true
  end

  def self.default_search_text() "search products and advisors" end

  def match_search(search_string)
    if search_string
      label.downcase.include?(search_string)
    else
      true
    end
  end

  #def reviews() Review.all( :product_idurl => idurl, :order => "created_at DESC") end



  def get_value(feature_idurl) hash_feature_idurl_value[feature_idurl] end
  def get_dimension_value(dimension_idurl) (x = get_value(dimension_idurl) and x.nan?) ? 0.0 : x end
  def set_value(feature_idurl, value) hash_feature_idurl_value[feature_idurl] = value end

  key :drivers_data, Hash, :default => {} # a list of data matchig this product to an external site (exemplae "amazon" => {"id" => "B002WB2P4O", "last_import_date" => "Mon May 31 11:19:05 +0200 2010" } )

  def get_driver(source,key) (drivers_data[source] || {})[key] end
  
  def self.update_from_driver(knowledge, source = "amazon")
    knowledge.get_products.inject([0,0,0]) do |(nb_products, nb_product_updated, nb_reviews_imported), product|
      review_last = product.review_last(:source => source)
      case source
        when "amazon" then nb_reviews_imported_for_source = product.create_amazon_reviews(knowledge, review_last ? review_last.written_at : nil )
      end
      (nb_reviews_imported += nb_reviews_imported_for_source; nb_product_updated += 1) if nb_reviews_imported_for_source > 0
      [nb_products + 1, nb_product_updated, nb_reviews_imported]
    end
  end

  def create_amazon_reviews(knowledge, written_after=nil)
    #Review.delete_with_opinions(:product_idurl => idurl, :source => Review::FromAmazon.default_category) # also destroy the attached opinions
    nb_reviews_imported = 0
    #begin
      if (amazon_ids = get_driver("amazon", "ids")) and amazon_ids.size > 0
        written_after ||= ((x = review_last) ? x.written_at : Date.today - 3000)
        for amazon_id in amazon_ids
          ApiAmazon.get_amazon_reviews(amazon_id, written_after).each do |amazon_review|
            FromAmazon.create_with_opinions(knowledge, self, get_value("amazon_url"), amazon_review)
            nb_reviews_imported += 1
          end
          puts "#{written_after};#{idurl};#{nb_reviews_imported}; reviews imported;http://www.amazon.com/dp/#{amazon_id}"
        end
      else
        #puts ";#{idurl};0; amazon_id missing"
      end
    #rescue Exception => e
    #  puts "*** #{idurl} (reviews #{nb_reviews_imported}) #{e.message}"
    #  e.backtrace.each { |m| puts "     #{m}"}
    #end
    nb_reviews_imported
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


  def generate_xml(top_node)
    node_product = super(top_node)
    node_product['knowledge_idurl'] = knowledge.idurl
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

  def to_xml()
    doc = XML::Document.new
    doc.root = to_xml_bis
    doc.to_s(:indent => true)
  end

  def to_xml_bis
    node_product = XML::Node.new("Product")
    node_product['idurl'] = idurl
    node_product['label'] = label


    # reviews
    node_product << node_reviews = XML::Node.new("reviews")
    reviews.each do |review|
      node_reviews << node_review = XML::Node.new(review.class.to_s)
      node_review['id'] = review.id.to_s
      nb_paragraphs, nb_opinions = review.nb_paragraphs_opinions
      node_review['nb_paragraphs'] = nb_paragraphs.to_s
      node_review['nb_opinions'] = nb_opinions.to_s
    end

    # features
    node_product << node_values = XML::Node.new("features_values")
    knowledge.each_feature do |feature|
      feature_idurl = feature.idurl
      if value = get_value(feature_idurl)
        node_values << node_value = XML::Node.new("Value")
        node_value['idurl'] = feature_idurl
        node_value << feature.value2xml(value)
      end
    end

    node_product
  end

  # return s all opinions of type Tip
  #base on mode either positif or negative
  def tips(mode)
    unless @opinions
      @opinions = Opinion::Tip.all(:product_ids => self.id)
    end
    @opinions.select  do |o|
      case mode
        when :pro then o.intensity >= 0.0
        when :con then o.intensity <= 0.0
      end
    end
  end



end

