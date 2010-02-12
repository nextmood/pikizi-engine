# using google API for reviews, products etc...
# see http://code.google.com/apis/gdata/articles/gdata_on_rails.html

require 'gdata'
require 'cgi'


def testg()
  client = GData::Client::GBase.new

  #puts gurl(:q => "digital+camera", :bq => "[brand:canon]")
  feed = client.get(gurl(:q => "iphone")).to_xml


  feed.elements.each('entry') do |entry|
    puts 'title: ' + entry.elements['title'].text
#    puts 'type: ' + entry.elements['category'].attribute('label').value
    puts 'updated: ' + entry.elements['updated'].text
    puts 'id: ' + entry.elements['id'].text

    # Extract the href value from each <atom:link>
    links = {}
    entry.elements.each('link') do |link|
      links[link.attribute('rel').value] = link.attribute('href').value
    end
    puts links.to_s
    puts entry
  end

  true
end

# see http://code.google.com/apis/base/docs/2.0/attrs-queries.html
def gsearch (options)
  client = GData::Client::GBase.new
  query_url = gurl(options)
  feed = client.get(query_url).to_xml
  results = {}
  feed.elements.each('entry') do |entry|
    entry_id =  entry.elements['id'].text
    result = {
            :title => entry.elements['title'].text,
            :updated => entry.elements['updated'].text
            }
    # Extract the href value from each <atom:link>
    links = {}
    entry.elements.each('link') do |link|
      links[link.attribute('rel').value] = link.attribute('href').value
    end
    result[:links] = links

    result[:entry] = entry

    results[entry_id] = result
  end
  [query_url, results, feed]
end

# see http://code.google.com/apis/base/docs/2.0/reference.html#ItemtypesFeeds
# options are :q (full text querry)
#             :bq structred query by feed
#             :feed_url (http://www.google.com/base/feeds/attributes)
def gurl(options)
  request_q = options[:q] ? "q=#{CGI.escape(options[:q])}"  : nil
  request_bq = options[:bq] ? "bq=#{CGI.escape(options[:bq])}"  : nil
  request_results_size = 250
  separator = (request_q and request_bq) ? "&" : nil
  params = "#{request_q}&#{request_bq}&#{request_results_size}"
  "http://www.google.com/base/feeds/snippets?#{params}"
end

