
#require "tactful_tokenizer"

require 'htmlentities'
require 'httpclient'

# check out http://www.instapaper.com/text?u=http://www.nextmood.com
# instpaper

class TextSource      # (one-one relationship to  review)
  include MongoMapper::Document

  key :content_raw, String
  key :content_normalized, String
  many :text_paragraphs # ordered list of Paragraph

  # :source => :text or :html
  # :title =>
  # :summary =>
  def initialize(content_raw, options)
    sep = options[:source] == "text" ? "\n" : "<br/>"
    self.content_raw =  content_raw
    self.normalize(options)
    self
  end

  def normalize(options)

    psep = "\n" # default separator

    self.content_normalized = content_raw.normalize(psep, options)

    # build the paragraphs tags
    self.text_paragraphs = []
    i = 0
    content_normalized.split(psep).inject(0) do |i, p|
      text_paragraph = TextParagraph.new(:from_char => i, :to_char => i + p.size - 1)
      self.text_paragraphs << text_paragraph
      text_paragraph.compute_sentences
      
      i + p.size + 1
    end

  end


  def semantic

  end

  def self.save_to_instapaper(url)
    api_request_url = "www.instapaper.com"
    instapaper_u = "info@nextmood.com"
    instapaper_p = "sarah9"

    # record in instapaper...
    HTTPClient.new.get("https://#{api_request_url}/api/add", :username => instapaper_u, :password => instapaper_p, :url => url)

    # retrieve the url as text
    puts "http://#{api_request_url}/text?u=#{url}"
    HTTPClient.new.get("http://#{api_request_url}/text", :u =>  url).body.content
  end

end


# needed extension
class String

  def remove_doublons!(pattern, new_s=nil)
    if pattern.is_a?(Array)
      pattern.each { |p| remove_doublons!(p, new_s) }
    else
      remove_doublons_bis!(pattern)
      gsub!(pattern, new_s) if new_s
      strip!
    end
    self
  end

  def remove_doublons_bis!(p)
    # recursive call...
    remove_doublons_bis!(p) if gsub!("#{p}#{p}", p)
  end

  # remove all html tags from a string
  def remove_all_html_tags!() gsub!(%r{</?[^>]+?>}, ""); strip! end

  # remove all given pattern from the strong
  def remove_all!(pattern)
    if pattern.is_a?(Array)
      pattern.each { |p| remove_all!(p) }
    else
      gsub!(pattern, "")
    end
  end

  def normalize(psep, options)

    case options[:source]

      when :text
        s = self.clone
        s.gsub!("\r", "")
        s.gsub!("\n ", "\n")
        s.gsub!(" \n", "\n")
        s.gsub!("\t\n", "\n")
        s.gsub!("\n\t", "\n")
        s.remove_doublons!(psep)
        s.remove_doublons!(["\t", " "], " ")
        s.strip

      when :html
        # cleanup a little bit
        s = HTMLEntities.new.decode(self)
        s.remove_all!(["\r", psep])
        s.remove_doublons!(["\t", " "], " ")
        s.strip!

        # TODO test the sanitizer gem...
        # self.s = Sanitize.clean(s, Sanitize::Config::RESTRICTED)

        # split the paragraphs/titles etc... according to a title
        pattern = case (options[:paragraph_tags] || :default)
                    when :only_br then /<br \/>|<br\/>|<br>/
                    when :default then /<br \/>|<br\/>|<br>|<p>|<\/p>|<h1>|<\/h1>/
                    when :only_p then /<p>|<\/p>/
        end

        s.split(pattern).collect do |paragraph_content|
          # for each paragraph cleanup a little bit
          paragraph_content.remove_all_html_tags!
          paragraph_content if paragraph_content.size > 0
        end.compact.join(psep)

      else
        raise "unknown options source=#{options[:source]} should be :text or :html"
    end

  end

end


# ===============================================================================================================
# classes bellow describe a part of the normalized_content and are embedded in a TextSource Object
#
#
class TextInterval
  include MongoMapper::EmbeddedDocument

  key :from_char, Integer
  key :to_char, Integer

  def to_s() _root_document.content_normalized[from_char..to_char] end

end

# describe a part of text, that will be subdivided
class TextContainer < TextInterval

  many :text_intervals, :polymorphic => true # recursive definition...
  def add_text_interval(text_interval, options={})
    options[:erase_first] ? self.text_intervals = [text_interval] : self.text_intervals << text_interval
  end

  def compute_sentences
    TextContainer.tactful_model.tokenize_text(to_s).inject(0) do |i, sentence|
      add_text_interval(TextSentence.new(:from_char => i, :to_char => i + sentence.size - 1))
      i + sentence.size
    end
  end

  def self.tactful_model() @@tactful_model ||= TactfulTokenizer::Model.new end

end

# using TactfulTokenizer
class TextParagraph < TextContainer

  def sentences() text_intervals end

end

class TextSummary < TextContainer
  def sentences() text_intervals.first end
  def set_sentence(text_sentence) add_text_interval(text_sentence, :erase_first => true) end
end

class TextTitle < TextContainer
  def sentence() text_intervals.first end
  def set_sentence(text_sentence) add_text_interval(text_sentence, :erase_first => true) end

end

class TextSentence < TextContainer
  def tokens() text_intervals end
  def add_token(text_token) add_text_interval(text_token) end
  def paragraph() _parent_document end
end

# =============================================================================
# Describe a list of token, matching word

# match a word
class TextToken < TextInterval
  def sentence() _parent_document end
end

