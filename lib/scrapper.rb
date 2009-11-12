require 'rubygems'
require 'open-uri'

class Scrapper
  attr_accessor :url, :reponse

  def initialize(url="http://www.lesnumeriques.com/article-494.html")
    self.url = url
    self.reponse = ""
  end

  def scrap
    # open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
    open(url, "User-Agent" => "Mozilla/5.0 (X11; U; Linux i686; fr; rv:1.9.1.1) Gecko/20090715 Firefox/3.5.1",
        "From" => "email@addr.com",
        "Referer" => "http://www.igvita.com/blog/") do |f|
      puts "Fetched document: #{f.base_uri}"
      puts "\\t Content Type: #{f.content_type}\\n"
      puts "\\t Charset: #{f.charset}\\n"
      puts "\\t Content-Encoding: #{f.content_encoding}\\n"
      puts "\\t Last Modified: #{f.last_modified}\\n\\n"

      # Save the response body
      self.response = f.read
    end
  end

end

