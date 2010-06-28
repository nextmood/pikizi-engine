require "driver"
require 'amazon/ecs'

# ====================================================================================================
# Amazon Interface
# Restriction
# no more than one request per second
# only to drive product purchase from amazon
# ====================================================================================================

# set the default options; options will be camelized and converted to REST request parameters.
# Access Key ID =  1PR0S6RKJ4MHVNWDMK82
# Secret access key =  ddcdZLkvJ9YQpySTwJiVEbrZI7w2zPZxz1Uz/2fs
# see http://docs.amazonwebservices.com/AWSECommerceService/2008-04-07/DG/

class DriverAmazon < Driver

  Amazon::Ecs.options = {:aWS_access_key_id => "1PR0S6RKJ4MHVNWDMK82", :aWS_secret_key => "ddcdZLkvJ9YQpySTwJiVEbrZI7w2zPZxz1Uz/2fs" }
  Amazon::Ecs.debug = true
  AMAZON_STORE = "All"

  # return a list of hash data (wuth at least :sid, :url_show, :label, :written_at
  def self.request_search(query_string)
    res = Amazon::Ecs.item_search(query_string, :type => "Keywords", :search_index => AMAZON_STORE, :response_group => 'Small')
    res.items.inject([]) do |l, item|
      l << { :sid => item.get(:asin),
             :url_show => item.get('detailpageurl'),
             :label => item.get('itemattributes/title'),
             :written_at => item.get('itemattributes/releasedate'),
             :manufacturer => item.get('itemattributes/manufacturer'),
             :product_group => item.get('itemattributes/productgroup') }
    end
  end


  # private.............
  
  def self.parse_amazon_element(node, tag, inner)
    if elt = node.at(tag)
      case inner
        when :html then elt.inner_html
        when :text then elt.inner_text
      end
    end
  end

end


# describe a product in Amazon, hashdata shoudl include at least :sid, :url_show, :label, :written_at
class DriverProductAmazon < DriverProduct

  # return a hash data  for a given product
  def self.request_detail(asin)
    res = Amazon::Ecs.item_lookup(asin, :response_group => 'Large')
    hash_data = {}
    item = res.first_item
    hash_data[:sid] = item.get('asin')
    hash_data[:url_show] = item.get('detailpageurl')
    hash_data[:label] = item.get('itemattributes/title')
    hash_data[:written_at] = item.get('itemattributes/releasedate')
    hash_data[:url_image] = item.get('largeimage/url')
    hash_data[:product_group] = item.get('itemattributes/productgroup')
    hash_data[:manufacturer] = item.get('itemattributes/manufacturer')
    hash_data[:price] = item.get('itemattributes/listprice/amount') # $x 100
    hash_data[:price] = hash_data[:price].to_f / 100.0 if hash_data[:price]

    hash_data[:descriptions] = []
    if descriptions = item/'editorialreview'
      descriptions.each do |description|
        hash_data[:descriptions] << {
          :source => DriverAmazon.parse_amazon_element(description, 'source', :html),
          :content => DriverAmazon.parse_amazon_element(description, 'content', :text) }
      end
    end

    hash_data[:similar_products] = []
    if similar_products = item/'similarproduct'
      similar_products.each do |similar_product|
        hash_data[:similar_products] << {
            :asin => DriverAmazon.parse_amazon_element(similar_product, 'asin', :html),
            :title => DriverAmazon.parse_amazon_element(similar_product, 'title', :html) }
      end
    end

    hash_data
  end



end

# describe a review, hash_data should include at least :sid, :content , :summary , :url_show , :written_at
class DriverReviewAmazon < DriverReview

  # Retrieve all reviews for a given sid, returns a list of hash
  def self.request_reviews(asin, written_after, page_index = 1)
    res = Amazon::Ecs.item_lookup(asin, :review_page => page_index, :response_group => 'Reviews')
    list_hash_reviews = []
    if (item = res.first_item) and reviews = item/'review'
      total_nb_pages = item.get('customerreviews/totalreviewpages').to_i
      reviews.each do |review|
        written_at = Time.parse(DriverAmazon.parse_amazon_element(review,'date', :html))
        raise "no date .... amazon" unless written_at
        if written_after.nil? or written_at > written_after
          customer_id = DriverAmazon.parse_amazon_element(review,'customerid', :html)
          list_hash_reviews << { :sid => "#{customer_id}-#{written_at}",
                            :content => DriverAmazon.parse_amazon_element(review,'content', :text),
                            :summary => DriverAmazon.parse_amazon_element(review,'summary', :html),
                            :url_show => "http://www.amazon.com",
                            :written_at => written_at,
                            :rating => DriverAmazon.parse_amazon_element(review,'rating', :html),
                            :helpfulvotes =>  DriverAmazon.parse_amazon_element(review,'helpfulvotes', :html),
                            :customerid => DriverAmazon.parse_amazon_element(review,'customerid', :html),
                            :totalvotes => DriverAmazon.parse_amazon_element(review,'totalvotes', :html) }
        end
      end
      if (list_hash_reviews.size == 0) or (page_index == total_nb_pages)
        list_hash_reviews
      else
        list_hash_reviews.concat(DriverReviewAmazon.request_reviews(asin, written_after, page_index+1))
      end
    end
    list_hash_reviews
  end

end
