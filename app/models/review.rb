require 'mongo_mapper'
require 'hpricot'

# describe a review
class Review < Root

  include MongoMapper::Document
  
  key :author, String
  key :source, String # amazon, user, expert, etc...
  key :source_url, String # external url for the review

  key :written_at, Date

  key :summary, String # summary of the review
  key :content, String # full content

  key :reputation, Float # the source reputation

  key :category, String # expert, :user etc... needed for weighted aggregation
  key :filename_xml, String
  key :knowledge_idurl, String

  key :_type, String # class management

  key :user_id, BSON::ObjectID # the user who recorded this opinion
  belongs_to :user

  key :knowledge_id, BSON::ObjectID
  belongs_to :knowledge

  key :product_idurls, Array
  key :product_ids, Array   # an array of BSON::ObjectID
  many :products, :in => :product_ids 

  many :opinions, :polymorphic => true, :order => :created_at.asc

  many :paragraphs, :order => :ranking_number.asc
  
  def opinions_through_paragraphs() paragraphs.inject([]) { |l, p| l.concat(p.opinions) } end

  def self.build_relational_links_debug
    hash_review_paragraph_opinions = Opinion.all.group_by { |o| o.review_id }.inject({}) do |h, (review_id, opinions)|

    end
  end

  timestamps!

  # -----------------------------------------------------------------
  # state machine
  

  state_machine :initial => :empty do


    state :empty

    state :to_review

    state :opinionated

    state :error 

    event :is_empty do
      transition all => :empty
    end

    event :has_opinions_reviewed_ok do
      transition all => :opinionated
    end

    event :has_opinions_to_review do
      transition all => :to_review
    end

    event :has_opinions_in_error do
      transition all => :error
    end

  end

  # to upate the status of a review
  def update_status(update_also_paragraphs=false)
    if opinions.any?(&:error?)
      has_opinions_in_error!
    elsif opinions.any?(&:to_review?)
      has_opinions_to_review!
    elsif opinions.any?(&:reviewed_ok?)
      has_opinions_reviewed_ok!
    else
      is_empty!
    end
    paragraphs.each(&:update_status) if update_also_paragraphs 
  end

  def self.list_states() Review.state_machines[:state].states.collect { |s| [s.name.to_s, Review.state_datas[s.name.to_s]] } end

  # label of state for UI
  def self.state_datas() { "empty" => { :label => "has no opinions", :color => "blue" },
                           "to_review" => { :label => "has at least one opinion waiting to be reviewed", :color => "orange" },
                           "opinionated" => { :label => "has at least one opinion valid", :color => "green" },
                           "error" => { :label => "has at least one opinion in error", :color => "red" } } end
  def state_label() Review.state_datas[state.to_s][:label] end
  def state_color() Review.state_datas[state.to_s][:color] end
  
  # -----------------------------------------------------------------
 

  
  def nb_paragraphs_opinions
    [paragraphs.count, paragraphs.inject(0) {|s, p| s += p.opinions.count } ]  
  end

  def get_reputation() source == Review::FromAmazon.default_category ? reputation + 1.0 : 1.0 end

  # all categories of reviews and their weights
  def self.categories() {"expert" => 10.0, "amazon" => 1.0, "user" => 2.0 } end
  def self.categories_as_percentage
    unless defined?(@@categories_as_percentage)
      sum_weight = self.categories.inject(0.0) { |s, (c, w)| s += w }
      @@categories_as_percentage = self.categories.inject({}) { |h, (c, w)| h[c] = (Float(w) * 100 / sum_weight).round; h }
    end
    @@categories_as_percentage
  end

  def self.categories_select() categories.collect {|k,v| [k,k] } end

  
  # destroy the record in mongo db, but first we need to remove all attached opinions
  def self.delete_with_opinions(find_options)
    Review.all(find_options).each { |review| Opinion.delete_all(:review_id => review.id) }
    Review.delete_all(find_options)
  end



  def cut_paragraph_at(paragraph, caret_position)
    max_size = paragraph.content.size - 1
    if caret_position > 0 or caret_position < max_size
      p1_content = paragraph.content[0 .. caret_position-1].strip
      p2_content = paragraph.content[caret_position .. max_size].strip
      if p1_content.size > 0 and p2_content.size > 0
        paragraph.content = p1_content
        paragraph.save
        new_ranking_number = paragraph.ranking_number + 1
        # recompute ranking numbers of next paragraphs
        paragraphs.select { |p| p.ranking_number >= new_ranking_number }.each {|p| p.ranking_number += 1; p.save }
        # new paragraph
        self.paragraphs.create(:content => p2_content, :ranking_number => new_ranking_number)
      end
    end
  end

  # break the content in paragraphs
  def split_in_paragraphs(mode)
    paragraphs.each(&:destroy) # delete paragraphs (should delete associated opinions)
    pattern = case mode
                    when "br" then /<br \/>|<br\/>|<br>/
                    when "p_br" then /<br \/>|<br\/>|<br>|<p>|<\/p>/
                    when "p" then /<p>|<\/p>/
                  end
    if pattern
      content.split(pattern).each_with_index do |paragraph_content, counter|
        paragraph_content = HTMLEntities.new.decode(paragraph_content).strip.remove_tags_html.remove_double_space.strip
        if paragraph_content != ""
          self.paragraphs.create(:ranking_number => counter, :content => paragraph_content, :review_id => self.id)
        end
      end
    else
      # 1 paragraph == whole content
      self.paragraphs.create(:ranking_number => 0, :content => HTMLEntities.new.decode(content).strip.remove_tags_html.remove_double_space.strip)
    end    
  end

  def self.to_xml
    doc = XML::Document.new
    doc.root = node_root = XML::Node.new("reviews")
    Review.all.each do |review|
      node_root << review.to_xml_bis if review.paragraphs.count > 0
    end
    doc.to_s(:indent => true)
  end

  def to_xml()
    doc = XML::Document.new
    doc.root = to_xml_bis
    doc.to_s(:indent => true)
  end

  def to_xml_bis
    node_review = XML::Node.new(self.class.to_s)
    node_review['id'] = id.to_s
    node_review['product_idurls'] = products.collect(&:idurl).join(", ")
    node_review['category'] = category
    node_review['status'] = status
    node_review['written_at'] = written_at.strftime(Root.default_datetime_format)


    (node_review << node_user = XML::Node.new("user"); node_user << user.rpx_identifier) if user_id
    (node_review << node_source = XML::Node.new("source"); node_source << source) if source
    (node_review << node_author = XML::Node.new("author"); node_author << author) if author
    (node_review << node_url = XML::Node.new("url"); node_url << source_url) if source_url
    (node_review << node_summary = XML::Node.new("summary"); node_summary << summary) if summary

    node_review << node_paragraphs = XML::Node.new("paragraphs")
    paragraphs.each do |paragraph|
      node_paragraphs << node_paragraph = XML::Node.new("Paragraph")
      node_paragraph << paragraph.content_without_html
      paragraph.opinions.each do |opinion|
        node_paragraph << opinion.to_xml_bis
      end
    end

    node_review
  end

  def origin(options={})
    l = []
    l << "by #{author}" if author
    l << "from #{source}" if source
    s = l.join(' ')
    if opinion = options[:opinion]
      s = "<a href='/edit_review/#{id}/#{opinion.paragraph_id}/#{opinion.id}' style='color:#00c0ff;' >#{s}</a>"
    else
      s = "<a href='#{source_url}' style='color:#00c0ff;' >#{s}</a>" if source_url
    end
    s = "<span style=\"#{options[:style]}\">#{s}</span>" if options[:style]
    s
  end

end

# reviews extracted from Amazon
class FromAmazon < Review

  def self.default_category() "amazon" end

  def self.create_with_opinions_4_all_products(knowledge)
    knowledge.products.each { |product| product.create_amazon_reviews(knowledge) }
  end

  def self.create_with_opinions(knowledge, product, amazon_url, amazon_review)
    r = Review::FromAmazon.create(:knowledge_idurl => knowledge.idurl,
                                  :knowledge => knowledge,
                                  :product_idurl => product.idurl,
                                  :product_id => product.id,
                                  :author => "amazon_customer_#{amazon_review[:customerid]}",
                                  :source => Review::FromAmazon.default_category,
                                  :source_url => amazon_url,
                                  :category => "amazon",
                                  :written_at => DateTime.parse(amazon_review[:date]),
                                  :summary => amazon_review[:summary],
                                  :content => amazon_review[:content],
                                  :reputation => Float(amazon_review[:totalvotes])  )
    r.generate_opinions(Float(amazon_review[:rating]))
  end

  def generate_opinions(rating)
    self.opinions << Opinion::Rating.create(:feature_rating_idurl => "overall_rating",
                           :min_rating => 1.0,
                           :max_rating => 5.0,
                           :rating => rating)
    split_in_paragraphs("p_br")
  end




end

# review generated by PH
class Inpaper < Review

  # break the content in paragraphs
#  def split_in_paragraphs
#    #url = File.open(url) if File.exist?(url)
#    #public/to_scrap/text_article.html
#    doc = Hpricot(url)
#    title = doc.at("//title").inner_html
#    original_url =  doc.at("body/div/a")['href']
#    ps = doc.search("//p").collect { |p| p.inner_html }
#    if title and original_url and ps.size > 0
#      r = Review.create(:title => title, :original_url => original_url, :knowledge_id => knowledge.id)
#      ps.each_with_index { |p, i| r.paragraphs.create(:ranking_number => i, :content => p) }
#      r
#    end
#  end

  def self.default_category() "expert" end

end

# review generated by PH
class FileXml < Review

  def self.default_category() "expert" end

  def self.create_with_opinions(knowledge)
    directory = "public/domains/#{knowledge.idurl}/reviews"
    get_entries(directory).each do |file_review_xml|
      if file_review_xml.has_suffix(".xml")
        xml_node = XML::Document.file("#{directory}/#{file_review_xml}").root
        product = Product.first(:idurl => xml_node['product_idurl'])
        raise "no product for #{xml_node['product_idurl']}" unless product
        # get or create API in mongo mapper ?
        r = FileXml.create(:filename => file_review_xml,
                           :knowledge => knowledge,
                           :knowledge_idurl => knowledge.idurl,
                           :product => product,
                           :product_idurl => product.idurl,
                           :author => xml_node['author'],
                           :category => Review::FileXml.default_category,
                           :source => xml_node['source'],
                           :source_url => xml_node['url'],
                           :written_at => xml_node['date'] ? FeatureDate.xml2date(xml_node['date']) : Date.today,
                           :reputation => 1)
        r.generate_opinions(xml_node)
      end
    end
  end


  def generate_opinions(xml_node)
    xml_node.find("FeatureOpinion").each do |node_feature_opinion|

      feature_rating_idurl = node_feature_opinion['idurl'] #dimension of rating

      # processing Rating Opinion
      node_feature_opinion.find("rating").each do |node_rating|
        node_content = node_rating.content.strip
        if (node_content = node_rating.content.strip) != ""
          opinion = Opinion::Rating.create(:feature_rating_idurl => feature_rating_idurl,
                                           :min_rating => Float(node_rating["min_rating"] || 0),
                                           :max_rating => Float(node_rating["max_rating"] || 10),
                                           :rating => Float(node_content))
          self.opinions << opinion
        end
      end

      # processing Tip Opinion
      node_feature_opinion.find("tip").each do |node_tip|
         intensity = node_tip["intensity"] || 1.0
         intensity = 1.0 if intensity == "pro"
         intensity = -1.0 if intensity == "cons"
         self.opinions << Opinion::Tip.create(:feature_rating_idurl => feature_rating_idurl,
                             :usage => node_tip["usage"],
                             :intensity => Float(intensity),
                             :label => node_tip.content.strip)
      end

      # processing Better Comparator Opinion
      node_feature_opinion.find("better").each do |node_better|
        self.opinions << Opinion::Comparator.create_from_xml(feature_rating_idurl, "better", node_better)
      end

      # processing Same Comparator  Opinion
      node_feature_opinion.find("same").each do |node_same|
        self.opinions << Opinion::Comparator.create_from_xml(feature_rating_idurl, "same", node_better)
      end

      # processing Worse Comparator  Opinion
      node_feature_opinion.find("worse").each do |node_worse|
        self.opinions << Opinion::Comparator.create_from_xml(feature_rating_idurl, "worse", node_better)
      end

    end
  end

end

