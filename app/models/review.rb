require 'mongo_mapper'

# describe an review of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Review < Root
  
  include MongoMapper::Document

  key :filename, String
  key :knowledge_idurl, String
  key :product_idurl, String
  key :author_email, String
  key :source, String
  key :source_url, String      # external url for the review
  key :written_at, Date
  key :feature_idurl, String
  key :label, String # summary of the review
  key :label_full, String # full content
  key :reputation, Float # the user reputation
  key :_type, String
  
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
        options_create = { :filename => file_review_xml,
                           :knowledge_idurl => knowledge.idurl,
                           :product_idurl => xml_node['product_idurl'],
                           :author_email => xml_node['author'],
                           :source => xml_node['source'],
                           :source_url => xml_node['url'],
                           :written_at => xml_node['date'] ? FeatureDate.xml2date(xml_node['date']) : Time.now }

        xml_node.find("FeatureOpinion").each do |node_feature_opinion|

          options_create[:feature_idurl] = node_feature_opinion['idurl']

          node_feature_opinion.find("rating").each do |node_rating|
            cleanup_options_create(options_create)
            options_create[:min_rating] = Float(node_rating["min_rating"] || 0)
            options_create[:max_rating] = Float(node_rating["max_rating"] || 10)
            node_content = node_rating.content.strip
            if node_content != ""
              options_create[:rating] = Float(node_content)
              Review::Rating.create(options_create)
            end
          end

          node_feature_opinion.find("tip").each do |node_tip|
             cleanup_options_create(options_create)
             options_create[:usage] = node_tip["usage"]
             intensity = node_tip["intensity"] || 1.0
             intensity = 1.0 if intensity == "pro"
             intensity = -1.0 if intensity == "cons"
             options_create[:intensity] = Float(intensity)
             options_create[:label] = node_tip.content.strip
             Review::Tip.create(options_create)
          end

          node_feature_opinion.find("better").each do |node_better|
            cleanup_options_create(options_create)
            options_create[:operator_type] = "better"
            options_create[:predicate] = node_better["predicate"]
            options_create[:label] = node_better.content.strip
            Review::Comparator.create(options_create)
          end
          node_feature_opinion.find("same").each do |node_same|
            cleanup_options_create(options_create)
            options_create[:operator_type] = "same"
            options_create[:predicate] = node_same["predicate"]
            options_create[:label] = node_same.content.strip
            Review::Comparator.create(options_create)
          end
          node_feature_opinion.find("worse").each do |node_worse|
            cleanup_options_create(options_create)
            options_create[:operator_type] = "worse"
            options_create[:predicate] = node_worse["predicate"]
            options_create[:label] = node_worse.content.strip
            Review::Comparator.create(options_create)
          end

        end
      end
    end
  end

  def self.generate_xml

  end



  private

  def self.cleanup_options_create(options_create)
    options_create[:operator_type] = nil
    options_create[:predicate] = nil
    options_create[:label] = nil
    options_create[:usage] = nil
    options_create[:intensity] = nil
    options_create[:min_rating] = nil
    options_create[:max_rating] = nil
    options_create[:rating] = nil
  end
end


class Rating < Review


  key :min_rating, Float
  key :max_rating, Float
  key :rating, Float



  def is_valid?() min_rating and max_rating and rating end

  def to_html() "#{rating} in [#{min_rating}, #{max_rating}]" end

end

class Comparator < Review

  key :operator_type, String
  key :predicate, String

  def to_html() "#{operator_type} predicate=#{predicate}:#{label}" end

  def is_valid?() ["best", "worse", "same"].include?(operator_type) and !Root.is_empty(predicate)  end

end


class Tip < Review

  key :usage, String
  key :intensity, Float

  def to_html() "usage=#{usage}, i=#{intensity}:#{label}" end

  def is_valid?() !Root.is_empty(usage) and !Root.is_empty(intensity) end

end