require 'amazon.rb'
require 'net/http'

# describe an instance of a product from an external source
# example a product in amazon

# describe a given source for a given knowledge

class Driver
  include MongoMapper::Document

  key :_type, String # class management

  key :knowledge_id, BSON::ObjectID
  belongs_to :knowledge

  key :config, Hash, :default => {} # dedicated to store information about how to access this driver/knowledge

  many :driver_products, :polymorphic => true
  key :timestamp_last_update, Time

  def nb_products() driver_products.count end
  def nb_reviews() driver_products.inject(0) {|c, db| c + db.nb_reviews } end

  def to_s() "#{self.class}" end

  # search for products, return a list of Driver Product objects
  def search(query_string)
    class_product = Kernel.const_get("DriverProduct#{source}")
    self.class.request_search(query_string).collect do |hash_data|
      hash_data[:driver_id] = id
      driver_product = class_product.birth(hash_data)
      class_product.first(:sid => driver_product.sid) || driver_product
    end
  end

  # get the details for a given product, return a driver product
  def get_details(sid)
    class_product = Kernel.const_get("DriverProduct#{source}")
    hash_data = class_product.request_detail(sid)
    hash_data[:driver_id] = id
    class_product.birth(hash_data)
  end

  # Download all reviews for all products since the last update
  # call the download_reviews for each driver_products
  # return the number of reviews downloaded
  def download_reviews
    t0 = Time.now
    nb_reviews_downloaded = driver_products.inject(0) do |nb, driver_product|
      nb_reviews_for_product_downloaded = driver_product.download_reviews.size
      Rails.logger.info "#{nb_reviews_for_product_downloaded} reviews downloaded for #{driver_product.sid}"
      nb + nb_reviews_for_product_downloaded
    end
    self.timestamp_last_update = Time.now
    duration = Time.now - self.timestamp_last_update
    average_duration = (nb_reviews_downloaded == 0 ? nil : duration.to_f / nb_reviews_downloaded.to_f )
    Rails.logger.info "#{nb_reviews_downloaded} reviews downloaded for #{self} in #{duration}s (average= #{average_duration}s/review)"
    nb_reviews_downloaded
  end


  def add_product(product_id, sid)
    driver_product = get_details(sid)
    driver_product.pkz_product_ids = [product_id]
    driver_product.save
    self.driver_products << driver_product
    Rails.logger.info "product #{driver_product} added to #{self}"
    driver_product
  end

  def self.restore
    knowledge = Knowledge.first
    Driver.delete_all
    DriverProduct.delete_all
    DriverReview.delete_all
    driver_amazon = DriverAmazon.create(:knowledge_id => knowledge.id)
    driver_cnet = DriverCnet.create(:knowledge_id => knowledge.id)
    driver_bestbuy = DriverBestbuy.create(:knowledge_id => knowledge.id)
    driver_twitter = DriverTwitter.create(:knowledge_id => knowledge.id)
    Product.all.each do |product|
      if (amazon_ids = product.get_driver("amazon","ids"))
        amazon_ids.each do |amazon_id|
          begin
            driver_product = driver_amazon.add_product(product.id, amazon_id)
            puts "product amazon #{amazon_id} added"
            driver_reviews = driver_product.download_reviews
            puts "product amazon #{amazon_id}, #{driver_reviews.size} reviews loaded"

          rescue
            puts "oups pb with amazon=#{amazon_id.inspect}"
          end
        end
      end
    end
    true
  end

  # utilities ....

  def self.as_float(s)
    begin
      Float(s)
    rescue
      nil
    end
  end

  def source() self.class.to_s.remove_prefix("Driver") end
end


# describe a product in a given referential
class DriverProduct
  include MongoMapper::Document

  key :_type, String # class management

  key :driver_id, BSON::ObjectID, :index => true
  belongs_to :driver

  key :pkz_product_ids, Array, :default => [] # the list of related products (usually one)
  def pkz_products() Product.find(pkz_product_ids) end
  def pkz_products_as_html() pkz_products.collect(&:label).join(", ") end
  
  key :sid, String
  key :label, String
  key :url_show, String
  key :url_image, String
  key :written_at, Time, :index => true              
  key :hash_data, Hash, :default => nil

  key :date_last_review, Time, :default => nil

  many :driver_reviews, :polymorphic => true, :order => "written_at DESC"

  # Download all reviews for this driver_product since the last update
  # return the list of driver_reviews downloaded and created in DB
  def download_reviews(written_after=nil)
    written_after = (written_after ? date_last_review : Time.now - (60 * 60 * 24 * 365 * 5))
    class_review = Kernel.const_get("DriverReview#{source}")    
    driver_reviews = class_review.request_reviews(sid, written_after).collect do |hash_data|
      hash_data[:driver_product_id] = id
      driver_review = class_review.birth(hash_data)
      driver_review.save
      self.driver_reviews << driver_review
      if driver_review.written_at
        self.date_last_review = driver_review.written_at if date_last_review.nil? or driver_review.written_at > date_last_review
      else
        puts "review from amazom (product #{id}) have no date #{driver_review.written_at}"
      end
      driver_review
    end
    save 
    driver_reviews
  end

  # create a new product from a hash data returned by a driver (don't save it)  
  def self.birth(hash_data)
    sid = hash_data.delete(:sid)
    label = hash_data.delete(:label)
    url_show = hash_data.delete(:url_show)
    written_at = hash_data.delete(:written_at)
    url_image = hash_data.delete(:url_image)    
    driver_id = hash_data.delete(:driver_id)
    self.new(:sid => sid, :label => label, :url_show => url_show, :written_at => written_at, :url_image => url_image, :driver_id => driver_id, :hash_data => hash_data)       
  end

  def to_s() "#{label}" end

  def extra_data_html
    l = hash_data.collect do |k,v|
      v = v.inspect unless v.is_a?(String)
      "<tr><td valign=\"top\">#{k}</td><td>#{v}</td></tr>"
    end
    l.sort! { |x1, x2| x1.size <=> x2.size }
    "<table border=\"1\">#{l.join}</table>"
  end

  def nb_reviews() driver_reviews.count end

  def source() self.class.to_s.remove_prefix("DriverProduct") end

end



class DriverReview
  include MongoMapper::Document

  key :_type, String # class management
  
  key :driver_product_id, BSON::ObjectID, :index => true
  belongs_to :driver_product

  key :sid, String
  key :content, String
  key :summary, String
  key :url_show, String
  key :written_at, Time, :index => true
  key :hash_data, Hash, :default => nil

  def to_s() "Review #{sid}" end

  # create a new review from a hash data returned by a driver (don't save it)
  def self.birth(hash_data)
    sid = hash_data.delete(:sid)
    content = hash_data.delete(:content)
    summary = hash_data.delete(:summary)
    url_show = hash_data.delete(:url_show)
    written_at = hash_data.delete(:written_at)
    driver_product_id  = hash_data.delete(:driver_product_id)
    self.new(:sid => sid, :content => content, :summary => summary, :url_show => url_show, :written_at => written_at, :driver_product_id => driver_product_id, :hash_data => hash_data)
  end

  def source() self.class.to_s.remove_prefix("DriverReview") end

end


