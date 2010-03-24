require 'mongo_mapper'

# describe a Dimension
# this is a hierarchy mechanism
# see http://railstips.org/blog/archives/2010/02/21/mongomapper-07-identity-map/
class Dimension

  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap
  
  key :idurl, String # unique url
  key :label, String
  key :min_rating, Integer, :default => 1
  key :max_rating, Integer, :default => 5

  # nested structure
  key :parent_id # a Dimension object
  belongs_to :parent, :class_name => "Dimension"
  
  # knowledge
  key :knowledge_id
  belongs_to :knowledge

  # related specifications (Hard features)
  many :specifications

  timestamps!



  def self.import
    Dimension.delete_all
    knowledge = Knowledge.first.link_back
    knowledge.each_feature do |feature|
      Dimension.create(:idurl => feature.idurl, :label => feature.label, :min_rating => 0, :max_rating => 10) if feature.is_a?(FeatureRating)
    end
    dimension_root = get_dimension_by_idurl("overall_rating")
    ["hardware_rating", "communication_rating", "overall_functionality_performance_rating", "apps_rating", "overall_value", "overall_spec"].each do |feature_idurl|
      unless get_dimension_by_idurl(feature_idurl)
        # create the dimension
        Dimension.create(:idurl => feature_idurl, :label => feature_idurl, :min_rating => 0, :max_rating => 10, :parent_id => dimension_root.id)
      end
    end

    knowledge.each_feature { |feature|
      if feature.is_a?(FeatureRating)
        dimension_parent = case feature.idurl_h.split('/').first
          when "hardware" then get_dimension_by_idurl("hardware_rating")
          when "communication" then get_dimension_by_idurl("communication_rating")
          when "overall_functionality_performance" then get_dimension_by_idurl("overall_functionality_performance_rating")
          when "apps_productivity" then get_dimension_by_idurl("apps_rating")
          when "media" then get_dimension_by_idurl("media_rating")
          else dimension_root
        end
        raise "error no dimension parent for #{feature.idurl_h}" unless dimension_parent
        dimension = get_dimension_by_idurl(feature.idurl)
        dimension.parent_id = dimension_parent.id unless dimension.id == dimension_parent.id 
        dimension.save
      end
    }
    knowledge.dimension_root = dimension_root
    knowledge.save
    true
  end

  def level() parent_id.blank? ? 1 : 1 + parent.level end
  
  def self.get_dimension_by_idurl(idurl) Dimension.first(:idurl => idurl) end

  # return all children
  def children() @children ||= Dimension.all(:knowledge_id => knowledge_id, :parent_id => id) end

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

  def get_feature_html()
    suffix = "#{feature_html_suffix}"
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

  def feature_html_suffix() "" end


  # ---------------------------------------------------------------------


end

