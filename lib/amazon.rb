#!/usr/bin/env ruby

# HOW TO USE  -> see bottom

# require 'rubygems'

require 'amazon/ecs'


=begin

def display(fieldname, content)
  puts "<field id=\"#{fieldname}\">#{content}</field>"
end

def amazon_product(asin)
  puts "***************Product Amazon #{asin}******************************************"
  amazon_product = ApiAmazon.get_amazon_product(asin)

  display("asin", amazon_product[:asin])
  display("detail_page_url", amazon_product[:detail_page_url])
  display("title", amazon_product[:title])
  display("image", amazon_product[:image])
  display("product_group", amazon_product[:product_group])
  display("manufacturer", amazon_product[:manufacturer])
  display("released_on", amazon_product[:released_on])
  display("price", amazon_product[:price])

  amazon_product[:descriptions] .each do |description|
    display("Description source", description[:source])
    display("content", description[:content])
  end

  amazon_product[:similar_products] .each do |similar_product|
    display("similar product: asin", similar_product[:asin]) #{similar_product[:title])
  end

end

def amazon_reviews(asin, max_page=nil)
  (reviews = ApiAmazon.get_amazon_reviews(asin, 1, max_page)).each  do |amazon_review|
    puts "***************Review******************************************"
    display("rating", amazon_review[:rating])
    display("helpfulvotes", amazon_review[:helpfulvotes])
    display("customerid", amazon_review[:customerid])
    display("totalvotes", amazon_review[:totalvotes])
    display("date", amazon_review[:date])
    display("summary", amazon_review[:summary])
    display("content", amazon_review[:content])
  end
  puts "=================================================================="
  puts "#{reviews.size} downloaded..."
end


=end


class ApiAmazon

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
  Amazon::Ecs.options = {:aWS_access_key_id => "1PR0S6RKJ4MHVNWDMK82", :aWS_secret_key => "ddcdZLkvJ9YQpySTwJiVEbrZI7w2zPZxz1Uz/2fs" }
  Amazon::Ecs.debug = true
  AMAZON_STORE = "All"

  def self.get_amazon_products(query_string)
    res = Amazon::Ecs.item_search(query_string, :type => "Keywords", :search_index => AMAZON_STORE, :response_group => 'Small')

    list_records = []
    res.items.each do |item|
      list_records << { :asin => item.get(:asin),
                  :detail_page_url => item.get('detailpageurl'),
                  :manufacturer => item.get('itemattributes/manufacturer'),
                  :product_group => item.get('itemattributes/productgroup'),
                  :title => item.get('itemattributes/title') }
    end

    [list_records, res.total_pages, res.total_results, res.item_page]
  end

  def self.get_amazon_product(asin)
    res = Amazon::Ecs.item_lookup(asin, :response_group => 'Large')
    amazon_product = {}
    item = res.first_item
    amazon_product[:asin] = item.get('asin')
    amazon_product[:detail_page_url] = item.get('detailpageurl')
    amazon_product[:title] = item.get('itemattributes/title')
    amazon_product[:image] = item.get('largeimage/url')
    amazon_product[:product_group] = item.get('itemattributes/productgroup')
    amazon_product[:manufacturer] = item.get('itemattributes/manufacturer')
    amazon_product[:released_on] = item.get('itemattributes/releasedate')
    amazon_product[:price] = item.get('itemattributes/listprice/amount') # $x 100
    amazon_product[:price] = amazon_product[:price].to_f / 100.0 if amazon_product[:price]

    amazon_product[:descriptions] = []
    if descriptions = item/'editorialreview'
      descriptions.each do |description|
        amazon_product[:descriptions] << {
          :source => ApiAmazon.parse_amazon_element(description, 'source', :html),
          :content => ApiAmazon.parse_amazon_element(description, 'content', :text) }
      end
    end

    amazon_product[:similar_products] = []
    if similar_products = item/'similarproduct'
      similar_products.each do |similar_product|
        amazon_product[:similar_products] << {
            :asin => ApiAmazon.parse_amazon_element(similar_product, 'asin', :html),
            :title => ApiAmazon.parse_amazon_element(similar_product, 'title', :html) }
      end
    end

    amazon_product
  end

  # Retrieve all reviews for a given ASIN
  def self.get_amazon_reviews(asin, written_after, page_index = 1)
    res = Amazon::Ecs.item_lookup(asin, :review_page => page_index, :response_group => 'Reviews')
    amazon_reviews = []
    if (item = res.first_item) and reviews = item/'review'
      total_nb_pages = item.get('customerreviews/totalreviewpages').to_i
      reviews.each do |review|
        written_at = Time.parse(ApiAmazon.parse_amazon_element(review,'date', :html))
        raise "no date .... amazon" unless written_at
        if written_after.nil? or written_at > written_after
          amazon_reviews << { :rating => ApiAmazon.parse_amazon_element(review,'rating', :html),
                              :helpfulvotes =>  ApiAmazon.parse_amazon_element(review,'helpfulvotes', :html),
                              :customerid => ApiAmazon.parse_amazon_element(review,'customerid', :html),
                              :totalvotes => ApiAmazon.parse_amazon_element(review,'totalvotes', :html),
                              :date => written_at,
                              :summary => ApiAmazon.parse_amazon_element(review,'summary', :html),
                              :content => ApiAmazon.parse_amazon_element(review,'content', :text) }
        end
      end
      if (amazon_reviews.size == 0) or (page_index == total_nb_pages)
        amazon_reviews
      else
        amazon_reviews.concat(ApiAmazon.get_amazon_reviews(asin, written_after, page_index+1))
      end
    end
    amazon_reviews
  end


  protected

  def self.parse_amazon_element(node, tag, inner)
    if elt = node.at(tag)
      case inner
        when :html then elt.inner_html
        when :text then elt.inner_text
      end
    end
  end

end


# HOW TO USE
# launch a terminal
# type: ruby amazon -p -r  #asin
# example: amazon -p -r B00212HNA0
# -p return information about the product (default)
# -r[nb_pages] return reviews, X number of pages


# blackberry_bold B001F7VN6M
# blackberry_pearl_flip B001J2TMAW<

=begin

asin = ARGV.last
amazon_product(asin) if ARGV.include?("-p") or ARGV.size == 1
if arg_review = ARGV.detect { |a| a[0..1] == "-r" }
  max_page = arg_review[2..1000]
  puts "max_page==#{max_page}"
  amazon_reviews(asin, max_page == "" ? nil : Integer(max_page))
end

=end
