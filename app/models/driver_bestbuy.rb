
require "driver"
require 'open-uri'
require "xml" 
require 'htmlentities'

#require "nokogiri" # html parser for bestbuy reviews

# ====================================================================================================
# Bestbuy Interface
# Restriction ?
# rights?
# ====================================================================================================

# Application Key ID =  pkz
# Secret access key =  9uftc8va88w366mgxuv8vny8
# see http://remix.bestbuy.com/?pagename=documentation&doc_active=505
# doc -> http://remix.bestbuy.com/?page_id=8

class DriverBestbuy < Driver

  def self.api_key() "9uftc8va88w366mgxuv8vny8" end

  # return a list of hash data (wuth at least :sid, :url_show, :label, :written_at
  def self.request_search(query_string)
    # bestbuy = "http://api.remix.bestbuy.com/v1/products%28name=iphone*%203g*%29?apiKey=9uftc8va88w366mgxuv8vny8"

    query_string_bis = query_string.split(" ").collect {|w| "#{w}*" }.join(' ')

    url_bestbuy = "http://api.remix.bestbuy.com/v1/products(name=#{query_string_bis})?apiKey=#{DriverBestbuy.api_key}"
    url_bestbuy = URI.escape(url_bestbuy)
    puts "url_bestbuy=\"#{url_bestbuy}\""
    doc = XML::Document.io(open(url_bestbuy))

    doc.find('product').inject([]) do |l, node_product|
      l << { :sid => DriverBestbuy.property(node_product, "sku"),
             :url_show => DriverBestbuy.property(node_product, "url"),
             :label => DriverBestbuy.property(node_product, "name"),
             :written_at => Time.parse(DriverBestbuy.property(node_product, "startDate")),
             :manufacturer => DriverBestbuy.property(node_product, "manufacturer"),
             :url_image => DriverBestbuy.property(node_product, "image"),
             :product_group => DriverBestbuy.property(node_product, "type") }
    end
  end

  def self.property(node_product, tag_name)
    node_tag = node_product.find_first(tag_name)
    node_tag.content  if node_tag
  end
end

# describe a product in Bestbuy, hashdata shoudl include at least :sid, :url_show, :label, :written_at
class DriverProductBestbuy < DriverProduct

  # return a hash data  for a given product
  def self.request_detail(sku)
    # http://developer.api.bestbuy.com/rest/v1.0/techProduct?iod=breadcrumb%2CuserRatings%2CproductAuxiliary&partKey=9xum54q22suq69e3cxcamqny&partTag=9xum54q22suq69e3cxcamqny&productId=31303113
    url_bestbuy = "http://api.remix.bestbuy.com/v1/products(sku=#{sku})?apiKey=#{DriverBestbuy.api_key}"
    url_bestbuy = URI.escape(url_bestbuy)

    doc = XML::Document.io(open(url_bestbuy))

    node_product = doc.find_first('product')
    hash_data =  { :sid => DriverBestbuy.property(node_product, "sku"),
             :url_show => DriverBestbuy.property(node_product, "url"),
             :label => DriverBestbuy.property(node_product, "name"),
             :written_at => Time.parse(DriverBestbuy.property(node_product, "startDate")),
             :manufacturer => DriverBestbuy.property(node_product, "manufacturer"),
             :url_image => DriverBestbuy.property(node_product, "image"),
             :product_group => DriverBestbuy.property(node_product, "type") }
    hash_data
  end




end



class DriverReviewBestbuy < DriverReview

  # Retrieve the last bestbuy review for a given sid, returns a list of one hash
  # sid is the sku number
  # see http://remix.bestbuy.com/?pagename=documentation&doc_active=762
  def self.request_reviews(sid, written_after, page_index = 1)
    
    url_bestbuy = "http://api.remix.bestbuy.com/v1/reviews(sku=#{sku}&submissionTime>=#{written_after.strftime('%Y-%m-%d')})?apiKey=#{DriverBestbuy.api_key}&page=#{page_index}"
    url_bestbuy = URI.escape(url_bestbuy)

    # http://api.remix.bestbuy.com/v1/reviews(submissionTime=2010-04-1*)?apiKey=bvn7tg3ftneqbun2h67ae7nu
    # http://api.remix.bestbuy.com/v1/reviews(rating=5.0&sku=8880044)?apiKey=bvn7tg3ftneqbun2h67ae7nu
    # http://api.remix.bestbuy.com/v1/reviews(submissionTime>=2010-05-1)?apiKey=bvn7tg3ftneqbun2h67ae7nu

    doc = XML::Document.io(open(url_bestbuy))

    node_reviews = doc.find_first('reviews')
    nb_pages = Integer(DriverBestbuy.property(node_reviews, "totalPages"))
    current_page = Integer(DriverBestbuy.property(node_reviews, "currentPage"))
    raise "error current_page=#{current_page} page_index=#{page_index}" unless current_page == page_index

    # map reviews...
    list_hash_reviews = node_reviews.find('review').inject([]) do |l, node_review|
        l <<  { :sid => DriverBestbuy.property(node_review, "id"),
                :comment => DriverBestbuy.property(node_review, "content"),
                :summary => DriverBestbuy.property(node_review, "title"),
                :written_at => Time.parse(DriverBestbuy.property(node_review, "submissionTime")),
                :rating => DriverBestbuy.property(node_review, "rating"),
                :customerid => DriverBestbuy.property(node_review, "reviewer/name") }
    end
    
    if page_index == nb_pages
      list_hash_reviews
    else
      list_hash_reviews.concat(DriverReviewBestbuy.request_reviews(sid, written_after, page_index + 1))      
    end

  end


end
