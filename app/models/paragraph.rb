# a sub-division of the content of a review
class Paragraph

  include MongoMapper::Document

  key :content, String # full content
  key :ranking_number, Integer # the first, 2nd third paragraph etc...

  many :opinions
  

end