require 'amazon.rb'

# describe an instance of a product from an external source
# example a product in amazon

# describe a give referential
class Source
  include MongoMapper::Document

  many :source_products, :polymorphic => true

  def download_reviews
    t0 = Time.now
    nb_reviews_downloaded = source_products.inject(0) do |nb, source_product|
      nb_reviews_downloaded_for_product = source_product.download_reviews(self)
      Rails.logger.info "#{nb_reviews_downloaded_for_product} reviews downloaded for #{source_product.sid}"
      nb + nb_reviews_downloaded_for_product
    end
    duration = Time.now - t0
    average_duration = (nb_reviews_downloaded == 0 ? nil : duration.to_f / nb_reviews_downloaded.to_f )
    Rails.logger.info "#{nb_reviews_downloaded} reviews downloaded for #{self} in #{duration}s (average= #{average_duration}s/review)"
  end

  # search for products, return a hash (see subclasses)
  def search(query_string)

  end

  # see subclasses
  def get_source_product_from_online(sid)

  end
  
  # this need to be call after job by subclasse
  def add_product(source_product)
    self.source_products << source_product
    source_product.update_headers
    source_product.save
    Rails.logger.info "product #{source_product} added to #{self}"
  end

  def to_s() "#{self.class}" end

  def nb_products() source_products.count end
  def nb_reviews() SourceReview.count(:source_id => id) end
end


# describe a product in a given referential
class SourceProduct
  include MongoMapper::Document

  key :sid, String
  key :label, String
  key :url_show, String

  key :source_id, BSON::ObjectID, :index => true
  key :hash_data, Hash, :default => nil
  key :written_at, Time, :index => true

  belongs_to :source
  many :source_reviews, :polymorphic => true, :order => "written_at DESC"
  def date_last_review() (r = source_reviews.first) ? r.written_at : nil end # TODO there is likely a big possible optimisation here


  def download_reviews(source)
    puts "download review for #{sid}"
  end

  def to_s() "#{label}" end

  def nb_reviews() source_reviews.count end

end



class SourceReview
  include MongoMapper::Document
  
  key :sid, String
  key :hash_data, Hash, :default => nil
  key :written_st, Time, :index => true

  key :source_id, BSON::ObjectID, :index => true
  belongs_to :source

  def to_s() "Review Amazon #{sid}" end
  
end


# ======================================================================================================================
# Amazon
# ======================================================================================================================

class SourceAmazon < Source

  def self.restore
    [Source, SourceProduct, SourceReview].each(&:delete_all)
    source_amazon = SourceAmazon.create # create singleton
    Product.all.each do |product|
      amazon_ids = (product.get_driver("amazon", "ids") || [])
      amazon_ids.each { |amazon_id| source_amazon.add_product(amazon_id)  }
    end
    source_amazon.save
    source_amazon.download_reviews
    true
  end

  def add_product(amazon_id)
    begin
      source_product_amazon =  get_source_product_from_online(amazon_id)
      source_product_amazon.save
      super(source_product_amazon)
    rescue
      Rails.logger.warn "i can't load product #{amazon_id}";nil
    end
  end

  # search for products, return a list of SourceProduct Object (not saved)
  #  hash_data details...
  #  :asin
  #  :detail_page_url
  #  :manufacturer
  #  :product_group
  #  :title
  def search(query_string)
    list_records, total_pages, total_results, item_page = ApiAmazon.get_amazon_products(query_string)
    list_records.collect do |hash_data| get_source_product_from_online(hash_data[:asin]) end
  end

  # return the product description from online
  def get_source_product_from_online(amazon_id)
    source_product = SourceProductAmazon.new(:sid => amazon_id, :hash_data => ApiAmazon.get_amazon_product(amazon_id), :source_id => id)
    source_product.update_headers
    source_product
  end

end


# describe a product in Amazon
# structure of  hash_data
# :asin
# :detail_page_url
# :title
# :image
# :product_group
# :manufacturer
# :released_on
# :price
# :descriptions   list of hash { :source => "xxx", :content => "" }
# :similar_products list of hash { :asin => "xxx", :title => "" }

class SourceProductAmazon < SourceProduct

  def update_headers
    self.label = hash_data[:title]
    self.url_show = hash_data[:detail_page_url]
    self.written_at = hash_data[:released_on]
  end
  
  def compute_url() end

  def download_reviews(source)
    written_after = self.date_last_review
    ApiAmazon.get_amazon_reviews(sid, written_after).inject(0) do |nb_upload, amazon_review_datas|
      source_review_written_at = amazon_review_datas[:date]
      raise "Error source_review_written_at=#{source_review_written_at.inspect} amazon_review_datas=#{amazon_review_datas.inspect}" unless source_review_written_at
      self.source_reviews << SourceReviewAmazon.create(:sid => "?", :hash_data => amazon_review_datas, :source_id => source.id, :written_at =>source_review_written_at)
      nb_upload + 1      
    end
  end

end



# describe a review in Amazon
# structure of  hash_data
#  :rating
#  :helpfulvotes
#  :customerid
#  :totalvotes
#  :date
#  :summary
#  :content
class SourceReviewAmazon < SourceReview

end

