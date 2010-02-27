require 'mongo_mapper'
require 'hpricot'

# describe a review
class Review < Root

  include MongoMapper::Document

  # this is the global rating
  key :min_rating, Float
  key :max_rating, Float
  key :rating, Float

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
  key :product_idurl, String

  key :_type, String # class management

  key :user_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :user

  key :knowledge_id, Mongo::ObjectID
  belongs_to :knowledge

  key :product_id, Mongo::ObjectID
  belongs_to :product

  many :opinions, :polymorphic => true

  key :paragraph_number, Integer, :default => 1 # the index for the paragraph
  many :paragraphs

  timestamps!



  def self.is_main_document() true end


  def get_reputation() source == Review::FromAmazon.default_category ? reputation + 1.0 : 1.0 end

  # all categories of reviews and their weights
  def self.categories() {"amazon" => 1.0, "user" => 2.0, "expert" => 10.0, "feature" => 1.0} end
  def self.categories_select() categories.collect {|k,v| [k,k] } end

  # destroy the record in mongo db, but first we need to remove all attached opinions
  def self.delete_with_opinions(find_options)
    Review.all(find_options).each { |review| Opinion.delete_all(:review_id => review.id) }
    Review.delete_all(find_options)
  end


  def paragraphs_sorted() paragraphs.sort {|p1, p2| p1.ranking_number <=> p2.ranking_number } end


  def self.opinion_types
    [["", ""], ["pro/cons", "tip"], ["compare with product", "comparator_product"], ["compare with feature", "comparator_feature"], ["related to feature", "feature_related"] ]
  end

  def cut_paragraph_at(paragraph, caret_position)
    max_size = paragraph.content.size - 1
    if caret_position > 0 or caret_position < max_size
      p1_content = paragraph.content[0 .. caret_position-1].strip
      p2_content = paragraph.content[caret_position .. max_size].strip
      p2_ranking_number = paragraph.ranking_number + 1
      if p1_content.size > 0 and p2_content.size > 0
        paragraph.content = p1_content
        paragraphs.each {|p| p.ranking_number += 1 if p.ranking_number >= p2_ranking_number }
        paragraphs << Paragraph.create(:ranking_number => p2_ranking_number, :content => p2_content)
        save
      end
    end
  end

  # break the content in paragraphs
  def split_in_paragraphs(mode)
    paragraphs.each(&:destroy) # delete paragraphs (should delete associated opinions)
    paragraphs_generated = []
    pattern = case mode
                    when "br" then /<br \/>|<br\/>|<br>/
                    when "p_br" then /<br \/>|<br\/>|<br>|<p>|<\/p>/
                    when "p" then /<p>|<\/p>/
                  end
    if pattern
      content.split(pattern).each do |paragraph_content|
        paragraph_content.strip!
        if paragraph_content != ""
          paragraphs_generated << Paragraph.create(:ranking_number => paragraphs_generated.size + 1, :content => paragraph_content)
        end
      end
    else
      # 1 paragraph == whole content
      paragraphs_generated << Paragraph.create(:ranking_number => 1, :content => content)
    end
    self.paragraphs = paragraphs_generated
    
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
                                  :product => product,
                                  :author => "amazon_customer_#{amazon_review[:customerid]}",
                                  :source => Review::FromAmazon.default_category,
                                  :source_url => amazon_url,
                                  :category => "amazon",
                                  :written_at => DateTime.parse(amazon_review[:date]),
                                  :feature_idurl => "overall_rating",
                                  :summary => amazon_review[:summary],
                                  :content => amazon_review[:content],
                                  :reputation => Float(amazon_review[:totalvotes]),
                                  :min_rating => 1,
                                  :max_rating => 5,
                                  :rating => Float(amazon_review[:rating]) )
    r.generate_opinions
  end

  def generate_opinions
    self.opinions << Opinion::Rating.create(:feature_rating_idurl => "overall_rating",
                           :min_rating => 1,
                           :max_rating => 5,
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
                           :written_at => xml_node['date'] ? FeatureDate.xml2date(xml_node['date']) : Time.now,
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
          if feature_rating_idurl == "overall_rating"
            self.min_rating = opinion.min_rating
            self.max_rating = opinion.max_rating
            self.rating = opinion.rating
            save
          end
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

