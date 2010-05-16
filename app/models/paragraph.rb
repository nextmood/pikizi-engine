require 'htmlentities'

# a sub-division of the content of a review
class Paragraph

  include MongoMapper::Document

  key :content, String # full content

  key :review_id, BSON::ObjectID
  key :reviewed_by, String # name of the author of reviewd this paragraphs (all opinions created if any)

  belongs_to :review

  key :ranking_number, Integer, :default => 0
  key :is_neutral, Boolean, :default => true

  many :opinions, :order => "created_at ASC", :polymorphic => true

  timestamps!
  
  # -----------------------------------------------------------------
  # state machine
  
  state_machine :initial => :empty do

    state :empty do
      def state_color() "blue" end
      def state_label() "No opinions" end
    end

    state :to_review do
      def state_color() "orange" end
      def state_label() "opinion(s) are waiting to be reviewed" end
    end

    state :opinionated do
      def state_color() "green" end
      def state_label() "has at least one opinion valid" end
    end

    state :error do
      def state_color() "red" end
      def state_label() "at least one opinion is unvalid" end
    end

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

  # to upate the status of a paragraph
  def update_status
    if opinions.any?(&:error?)
      has_opinions_in_error!
    elsif opinions.any?(&:to_review?)
      has_opinions_to_review!
    elsif opinions.any?(&:reviewed_ok?)
      has_opinions_reviewed_ok!
    else
      is_empty!
    end
  end

  def self.list_states() Paragraph.state_machines[:state].states.collect { |s| s.name.to_s } end

  # -----------------------------------------------------------------

  def content_without_html
    @content_without_html ||= HTMLEntities.new.decode(content).strip.remove_tags_html.remove_double_space
  end



end

