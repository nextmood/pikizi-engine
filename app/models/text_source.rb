
class TextSource      # (this is the review)
  include MongoMapper::Document

  key :content_raw, String
  key :content_normalized, String
  many :text_paragraphs
  many :text_sentences
  many :text_tokens

  def initialize(content_raw)
    self.content_raw = content_raw
  end

  def normalize
      
  end

  def semantic

  end


end

class TextInterval
  include MongoMapper::EmbeddedDocument

  key :from_char, Integer
  key :to_char, Integer

  def to_s() _parent.content_normalized[from_char, to_char] end

end

class TextTag < TextInterval

  many :text_tags, :polymorphic => true # recursive definition...
  def add_tag(text_tag) self.text_tags << text_tag end
  
end

class TextParagraph < TextTag
  def sentences() text_tags.select { |tt| tt.is_a?(TextSentence) } end
end

class TextSentence < TextTag
  key :index_paragraph, Integer # in which paragraph is this sentence
  def paragraph() _parent.paragraphs[index_paragraph] end
  def tokens() text_tags.select { |tt| tt.is_a?(TextToken) } end
end

# match a word
class TextToken < TextTag
  key :sentence_interval, TextInterval

end

class TextWordnet < TextToken
  
end

class TextComparaison < TextToken

end
