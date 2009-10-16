# html scrapper
# see http://www.igvita.com/2007/02/04/ruby-screen-scraper-in-60-seconds/

require 'open-uri'
require 'hpricot'

class Scrapper
  attr_accessor :url, :response

  def initialize(url= "http://www.igvita.com/blog")
    self.url = url
    self.response = ''
  end

  def scrap
    # open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
    open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}",
        "From" => "test@google.com",
        "Referer" => "http://www.google.com") do |f|
                          puts "Fetched document: #{f.base_uri}"
                          puts "  Content Type: #{f.content_type}"
                          puts "  Charset: #{f.charset}"
                          puts "  Content-Encoding: #{f.content_encoding}"
                          puts "  Last Modified: #{f.last_modified}\n"

                          # Save the response body
                          self.response = f.read
    end
    self
  end

  def extract
    #Rdoc: http://code.whytheluckystiff.net/hpricot/
    doc = Hpricot(response)

    # Retrive number of comments
    #  - Hover your mouse over the 'X Comments' heading at the end of this article
    #  - Copy the XPath and confirm that it's the same as shown below
    puts (doc/"/html/body/div[3]/div/div/h2").inner_html

    # Pull out first quote (<blockquote> .... </blockquote>)
    # - Note that we don't have to use the full XPath, we can simply search for all quotes
    # - Because this function can return more than one element, we will only look at 'first'
#    puts (doc/"blockquote/p").first.inner_html

    # Pull out all other posted stories and date posted
    # - This searh function will return multiple elements
    # - We are going to print the date, and then print the article name beside it
    (doc/"/html/body/div[4]/div/div[2]/ul/li/a/span").each do |article|
        puts "#{article.inner_html} :: #{article.next_node.to_s}"
    end
  end
  
end


