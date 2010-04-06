require 'mongo_mapper'

# describe a Dimension
# this is a hierarchy mechanism
# see http://railstips.org/blog/archives/2010/02/21/mongomapper-07-identity-map/
class Dimension

  include MongoMapper::Document
  #plugin MongoMapper::Plugins::IdentityMap
  
  key :idurl, String # unique url
  key :label, String
  key :min_rating, Integer, :default => 1
  key :max_rating, Integer, :default => 5
  key :_type, String # class management
  key :ranking_number, Integer, :default => 0
  key :is_aggregate, Boolean, :default => false
  
  # nested structure
  key :parent_id # a Dimension object
  belongs_to :parent, :class_name => "Dimension"
  many :children_db, :class_name => "Dimension", :foreign_key => "parent_id", :order => "ranking_number"

  # knowledge
  key :knowledge_id
  belongs_to :knowledge

  # opinions
  many :opinions, :class_name => "Opinion", :polymorphic => true, :foreign_key => :dimension_ids
  
  # related specifications (Hard features)
  many :specifications

  timestamps!



  def self.import
    Dimension.delete_all
    knowledge = Knowledge.first.link_back
    knowledge.each_feature do |feature|
      Dimension.create(:idurl => feature.idurl, :label => feature.label, :min_rating => 0, :max_rating => 10, :knowledge_id => knowledge.id) if feature.is_a?(FeatureRating)
    end
    dimension_root = get_dimension_by_idurl("overall_rating")
    Dimension.all.each {|d| (d.parent_id = dimension_root.id; d.save) unless d.id == dimension_root.id }
    knowledge.dimension_root = dimension_root
    knowledge.save
    Opinion.update2_opinion
    true
  end

  def level() parent_id.blank? ? 1 : 1 + parent.level end
  
  def self.get_dimension_by_idurl(idurl) Dimension.first(:idurl => idurl) end

  # return all children
  def children() @children ||= children_db end

  def product_template_comment() "a number between #{min_rating} and #{max_rating}" end

  # define the distance between  2 products for this feature
  def distance_metric(product1, product2) (get_value(product1) - get_value(product2)).abs end

  def get_value_01(product) product.get_value(idurl).to_f end

  def get_value_in_min_max_rating(product) get_value_in_min_max_rating_bis(get_value_01(product)) end

  def get_value_in_min_max_rating_bis(value_01)
    value_01 * (max_rating - min_rating) + min_rating
  end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is a float between 0 and 1

  def get_value_html(product)
    if value = get_value_01(product)
      stars_html(value)
    end
  end

  def stars_html(value_01)
    Root.stars_html(get_value_in_min_max_rating_bis(value_01), max_rating)
  end

  def get_value(product) product.get_value(idurl) end

  # this is included in a form
  def get_value_edit_html(product)
    "<div class=\"field\">
      <span>rating (min=#{min_rating}, max=#{max_rating})</span>
      <input type='text' name='feature_#{idurl}' value='#{get_value(product)}' />
    </div>"
  end

  def get_specification_html()
    suffix = "#{specification_html_suffix}"
    "<span title=\"rating (min=#{min_rating}, max=#{max_rating})\">#{label} #{suffix} </span>"
  end

  # this is included in a form
  def get_feature_edit_html()
    super() << "<div class=\"field\">
                   min=<input name=\"min_rating\" type='text' value=\"#{min_rating}\" size=\"2\" />
                   max=<input name=\"max_rating\" type='text' value=\"#{max_rating}\" size=\"2\" />
                </div>"
  end


  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) Float(content_string.strip) end
  def value2xml(value) value.to_s end

  def specification_html_suffix() "" end


  # ---------------------------------------------------------------------


end


