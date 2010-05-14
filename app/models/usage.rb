require 'mongo_mapper'
require 'hpricot'

# describe a review
class Usage

  include MongoMapper::Document

  # this is the  XXX for opinion
  # refers to a combinaison of dimension/rating
  # refers to one or more hard-feature

  key :label, String

  key :user_id, BSON::ObjectID # the user who recorded first this  usage
  belongs_to :user

  key :knowledge_id, BSON::ObjectID
  belongs_to :knowlege

  key :nb_opinions, Integer, :default => 0
  def self.compute_nb_opinions() Usage.all.each(&:compute_nb_opinions) end
  def compute_nb_opinions() update_attributes(:nb_opinions => Opinion.count(:usage_ids => id)) end
  def opinions() @opinions ||= Opinion.all(:usage_ids => id) end
  
  timestamps!

  def display_as() label.gsub(' ', '_').downcase[0.80] end

  def self.similar_to(input)
    input = input.downcase
    Usage.all(:order => "label").select { |u| u.label.downcase.index(input) }.collect(&:label)  
  end

  def related_dimensions
    unless @related_dimensions
      set_dimension_ids = opinions.inject(Set.new) { |s, opinion|  s.add(opinion.dimension_ids) }
      @related_dimensions = Dimension.find(set_dimension_ids.to_a)
    end
    @related_dimensions
  end

  # return all usages, having at least one opinion matching this dimension
  def self.get_list_for_dimension(dimension_id, just_count=false)
    opinions_with_at_least_dimension_id = Opinion.all(:dimension_ids => dimension_id)
    puts "opinions_with_at_least_dimension_id=#{opinions_with_at_least_dimension_id.size}"
    set_usage_ids = opinions_with_at_least_dimension_id.inject(Set.new) { |s, opinion| s.add(opinion.usage_ids); s }
    Usage.find(set_usage_ids.to_a)
  end

  def destroy
    # delete all reference to this usage in the opinions
    opinions.each { |opinion| opinion.usage_ids.delete(self.id); opinion.save }
    super
  end
  
end

