require 'htmlentities'

# a sub-division of the content of a review
class Paragraph

  include MongoMapper::Document

  key :content, String # full content

  key :review_id, BSON::ObjectID
  key :reviewed_by, String # name of the author of reviewd this paragraphs (all opinions created if any)

  belongs_to :review

  key :ranking_number, Integer, :default => 0

  many :opinions, :order => "created_at ASC", :polymorphic => true

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

  def self.list_states() Paragraph.state_machines[:state].states.collect { |s| [s.name.to_s, Paragraph.state_datas[s.name.to_s]] } end

  # label of state for UI
  def self.state_datas() { "empty" => { :label => "has no opinions", :color => "lightblue" },
                           "to_review" => { :label => "has at least one opinion waiting to be reviewed", :color => "orange" },
                           "opinionated" => { :label => "has at least one opinion valid", :color => "lightgreen" },
                           "error" => { :label => "has at least one opinion in error", :color => "red" } } end
  def state_label() Paragraph.state_datas[state.to_s][:label] end
  def state_color() Paragraph.state_datas[state.to_s][:color] end

  # -----------------------------------------------------------------

  def content_without_html
    @content_without_html ||= HTMLEntities.new.decode(content).strip.remove_tags_html.remove_double_space
  end

  def content_highlight(s)
    content.gsub(s, "<span color='red'>#{s}</span>")  
  end

end

