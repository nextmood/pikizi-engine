require 'mongo_mapper'

# describe an review of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Review < Root
  
  include MongoMapper::Document

  key :filename, String
  key :knowledge_idurl, String
  key :product_idurl, String
  key :author, String
  key :source, String
  key :url, String      # external url for the review
  key :written_at, Array
  key :datas, Array

  key :user_id, String
  belongs_to :user
  
  timestamps!


  def self.is_main_document() true end

  def self.initialize_from_xml(knowledge)
    Review.find(:all).each(&:destroy)
    directory = "public/domains/#{knowledge.idurl}/reviews"
    get_entries(directory).each do |file_review_xml|
      if file_review_xml.has_suffix(".xml")
        xml_node = XML::Document.file("#{directory}/#{file_review_xml}").root
        review = Review.create(:filename => file_review_xml,
                               :knowledge_idurl => knowledge.idurl,
                               :product_idurl => xml_node['product_idurl'],
                               :author => xml_node['author'],
                               :source => xml_node['source'],
                               :url => xml_node['url'],
                               :written_at => xml_node['date'] ? FeatureDate.xml2date(xml_node['date']) : Time.now,
                               :datas => [])
        product = Product.load(review.product_idurl)
        xml_node.find("FeatureOpinion").each do |node_feature_opinion|
          opinion = Opinion.new(node_feature_opinion['idurl'])

          node_feature_opinion.find("Rated").each do |node_rating|
            min_rating = node_rating["min_rating"] || 0   
            max_rating = node_rating["max_rating"] || 10
            node_content = node_rating.content.strip
            opinion.add_rating(min_rating, max_rating, Float(node_content)) if node_content != ""
          end

          node_feature_opinion.find("tip").each do |node_tip|
           usage = node_tip["usage"]
           intensity = node_tip["intensity"] || 1.0
           intensity = 1.0 if intensity == "pro"
           intensity = -1.0 if intensity == "cons"
           opinion.add_tip(usage, Float(intensity), node_tip.content.strip)
          end

          node_feature_opinion.find("better").each do |node_better|
            opinion.add_comparator(:better, node_better["predicate"], node_better.content.strip)
          end
          node_feature_opinion.find("same").each do |node_same|
            opinion.add_comparator(:same, node_same["predicate"], node_same.content.strip)
          end
          node_feature_opinion.find("worse").each do |node_worse|
            opinion.add_comparator(:worse, node_worse["predicate"], node_worse.content.strip)
          end

          puts "feature_idurl=#{opinion.feature_idurl} product_idurl=#{review.product_idurl} author_idurl=#{review.author}  source=#{review.source} url=#{review.url} date=#{review.written_at} ratings=#{opinion.ratings.inspect} tips=#{opinion.tips.inspect} comparators=#{opinion.comparators.inspect}" if opinion.ratings.size >0 and opinion.ratings.first.last 

          review.datas << opinion.to_data
          review.save
        end
      end
    end
  end

  def self.generate_xml

  end
  
end

class Opinion

  attr_accessor :feature_idurl, :ratings, :comparators, :tips
  
  def initialize(feature_idurl, ratings=nil, comparators=nil, tips=nil)
    @feature_idurl = feature_idurl
    @ratings = ratings || []
    @comparators = comparators || []
    @tips = tips || []
  end

  def to_data() [@feature_idurl, @ratings, @comparators, @tips] end

  def add_rating(min_rating, max_rating, rating)
    @ratings << [min_rating, max_rating, rating]
  end

  def add_comparator(type, predicate, label)
    @comparators << [type, predicate, label]
  end

  def add_tip(usage, intensity, label)
    @tips << [usage, intensity, label]
  end
  
end