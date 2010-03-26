# a sub-division of the content of a review
class Paragraph

  include MongoMapper::Document

  key :content, String # full content

  key :review_id, Mongo::ObjectID
  belongs_to :review

  key :ranking_number, Integer, :default => 0

  many :opinions, :polymorphic => true

  
end