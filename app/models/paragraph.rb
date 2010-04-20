require 'htmlentities'

# a sub-division of the content of a review
class Paragraph

  include MongoMapper::Document

  key :content, String # full content

  key :review_id, Mongo::ObjectID
  key :reviewed_by, String # name of the author of reviewd this paragraphs (all opinions created if any)

  belongs_to :review

  key :ranking_number, Integer, :default => 0

  many :opinions, :polymorphic => true

  def content_without_html
    @content_without_html ||= HTMLEntities.new.decode(content).strip.remove_tags_html.remove_double_space
  end



end

