require "driver"
require 'open-uri'
require "xml" 
require 'htmlentities'

#require "nokogiri" # html parser for cnet reviews

# ====================================================================================================
# Cnet Interface
# Restriction
# no more than 2 request per second   / 2500 days
# rights?
# ====================================================================================================

# set the default options; options will be camelized and converted to REST request parameters.
# Application Key ID =  pkz
# Secret access key =  9xum54q22suq69e3cxcamqny
# see http://developer.api.cnet.com/dashboard.html?partTag=9xum54q22suq69e3cxcamqny


class DriverCnet < Driver

  def self.api_key() "9xum54q22suq69e3cxcamqny" end

  # return a list of hash data (wuth at least :sid, :url_show, :label, :written_at
  def self.request_search(query_string)
    # url_cnet = "http://developer.api.cnet.com/rest/v1.0/techProductSearch?partKey=9xum54q22suq69e3cxcamqny&partTag=9xum54q22suq69e3cxcamqny&query=nokia&iod=none&start=0&limit=10"
    url_cnet = "http://developer.api.cnet.com/rest/v1.0/techProductSearch?partKey=#{DriverCnet.api_key}&partTag=#{DriverCnet.api_key}&query=#{URI.escape(query_string)}&iod=none&start=0&limit=10"
    doc = XML::Document.io(open(url_cnet))
    doc.root.namespaces.default_prefix = 'ns'

    doc.find('ns:TechProducts/ns:TechProduct').inject([]) do |l, node_techproduct|
      cnet_review_url = node_techproduct.find_first("ns:ReviewURL").content
      l << { :sid => node_techproduct["id"],
             :url_show => cnet_review_url,
             :label => node_techproduct.find_first("ns:Name").content,
             :written_at => Time.parse(node_techproduct.find_first("ns:PublishDate").content),
             :manufacturer => node_techproduct.find_first("ns:Manufacturer/ns:Name").content,
             :product_group => node_techproduct.find_first("ns:Category")["xlink:href"] }
    end
  end

end

# describe a product in Cnet, hashdata shoudl include at least :sid, :url_show, :label, :written_at
class DriverProductCnet < DriverProduct

  # return a hash data  for a given product
  def self.request_detail(sid)
    # http://developer.api.cnet.com/rest/v1.0/techProduct?iod=breadcrumb%2CuserRatings%2CproductAuxiliary&partKey=9xum54q22suq69e3cxcamqny&partTag=9xum54q22suq69e3cxcamqny&productId=31303113
    url_cnet = "http://developer.api.cnet.com/rest/v1.0/techProduct?iod=breadcrumb%2CuserRatings%2CproductAuxiliary&partKey=#{DriverCnet.api_key}&partTag=#{DriverCnet.api_key}&productId=#{sid}"
    doc = XML::Document.io(open(url_cnet))
    doc.root.namespaces.default_prefix = 'ns'
    node_techproduct = doc.find_first('//ns:TechProduct')
    cnet_review_url = node_techproduct.find_first("ns:ReviewURL").content
    hash_data = { :sid => node_techproduct["id"],
                  :url_show => cnet_review_url,
                  :label => node_techproduct.find_first("ns:Name").content,
                  :written_at => Time.parse(node_techproduct.find_first("ns:PublishDate").content),
                  :url_image => node_techproduct.find_first("ns:ImageURL").content,
                  :manufacturer => node_techproduct.find_first("ns:Manufacturer/ns:Name").content,
                  :product_group => node_techproduct.find_first("ns:Category")["xlink:href"],
                  :specs => node_techproduct.find_first("ns:Specs").content,
                  :edit_choice_boolean => node_techproduct.find_first("ns:EditorsChoice").content,
                  :editor_rating => (n = node_techproduct.find_first("ns:EditorsRating"); { :rating => Driver.as_float(n.content), :max => Driver.as_float(n["OutOf"]) }),
                  :user_rating => (n = node_techproduct.find_first("ns:UserRatingSummary/ns:Rating"); { :rating => Driver.as_float(n.content), :max => Driver.as_float(n["OutOf"]) }),
                  :user_rating_total_votes => Float(node_techproduct.find_first("ns:UserRatingSummary/ns:TotalVotes").content),
                  :category => node_techproduct.find_first("ns:Category/ns:Title").content }
    hash_data
  end




end



class DriverReviewCnet < DriverReview

  # Retrieve the last cnet review for a given sid, returns a list of one hash
  def self.request_reviews(sid, written_after, page_index = 1)
    html_data = Net::HTTP.get_response(URI.parse(self.request_detail(sid)[:url_show])).body
    # TODO parse html to retrieve review
    []
  end


end
