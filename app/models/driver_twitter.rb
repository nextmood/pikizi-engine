require "driver"
require 'twitter'

# ====================================================================================================
# Twitter Interface / Search
# see http://twitter.rubyforge.org/
# ====================================================================================================

# this map a search for a given search
class DriverTwitter < Driver

  # return a list of one hash data (with at least :sid, :url_show, :label, :written_at
  def self.request_search(query_string)
    twitter_query = Twitter::Search.new
    query_string.split(" ").each { |word| twitter_query.containing(word.strip) }
    twitter_query.lang("en").result_type(:recent).fetch().results.collect do |tweet|
      {  :sid => query_string,
         :url_show => tweet.profile_image_url,
         :label => tweet.text,
         :written_at => Time.parse(tweet.created_at) }
    end
  end

end

#  describe a search in twitter
# describe a search string for Twitter, hash_data should include at least :sid, :url_show, :label, :written_at
class DriverProductTwitter < DriverProduct

  # return a hash data  for a given product
  def self.request_detail(query_string)
    twitter_query = Twitter::Search.new
    query_string.split(" ").each { |word| twitter_query.containing(word.strip) }
    results = twitter_query.lang("en").result_type(:recent).fetch().results
    if tweet = results.first
        hash_data = {  :sid => query_string,
                       :url_show => tweet.profile_image_url,
                       :label => tweet.text,
                       :written_at => Time.parse(tweet.created_at),
                       :url_image => Twitter.user(tweet.from_user).profile_image_url }
        results.each { |t| hash_data["tweet_#{t.id}"] = "<div class='pkz_small'>#{t.from_user} @ #{t.created_at}</div>#{t.text}" }
        hash_data
    end    
  end

end



class DriverReviewTwitter < DriverReview

  # Retrieve the last twitter review for a given sid, returns a list of one hash
  def self.request_reviews(sid, written_after, page_index = 1)
    html_data = Net::HTTP.get_response(URI.parse(self.request_detail(sid)[:url_show])).body
    # TODO parse html to retrieve review
    []
  end


end
