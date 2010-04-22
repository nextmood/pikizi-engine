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
  key :explanation_aggregation, String
  
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

  def get_value_01(product) (x = product.get_value(idurl)) ? x.to_f : nil end

  def get_value_in_min_max_rating(product) get_value_in_min_max_rating_bis(get_value_01(product)) end
  def get_value_in_min_max_rating_html(product) get_value01_in_min_max_rating_html(get_value_01(product)) end
  def get_value01_in_min_max_rating_html(value01) value01 ? "#{'%.1f' % get_value_in_min_max_rating_bis(value01)}" : 'n/a' end

  def get_value_in_min_max_rating_bis(value_01) value_01 * (max_rating - min_rating) + min_rating end

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
  # Compute aggreagtion
  # ---------------------------------------------------------------------


  

  def compute_aggregation(all_products, only_product=nil)
    ratings, comparaisons = compute_aggregation_ratings_comparaisons(only_product)
    hash_product_2_category_average_rating01 = compute_hash_product_2_category_average_rating01(ratings, all_products, only_product)
    hash_product_2_average_rating01 = compute_hash_product_2_average_rating01(hash_product_2_category_average_rating01, only_product)
    hash_product_2_average_sub_dimensions = compute_hash_product_2_average_sub_dimensions(all_products, only_product)
    elo = compute_elo(comparaisons, all_products)
    hash_pid_2_average_mixed = combine_rating_elo_sub_automatic(hash_product_2_average_rating01, elo, hash_product_2_average_sub_dimensions, only_product)
  end

  def compute_aggregation_ratings_comparaisons(only_product)
    opinions.inject([[], []]) do |(l_ratings, l_comparaisons), opinion|
      if only_product.nil? or opinion.concern?(only_product)
        if opinion.generate_rating?
          l_ratings << opinion
        elsif opinion.generate_comparaison?
          l_comparaisons << opinion
        else
          raise "unknown opinion"
        end
      end
      [l_ratings, l_comparaisons]
    end
  end


  def compute_hash_product_2_category_average_rating01(ratings, all_products, only_product)
    hash_product_2_list_of_category_average_rating01 = ratings.inject({}) do |h, opinion_rating|
      # generate_ratings yield with pid, weight, rating_01
      opinion_rating.for_each_rating(all_products)  do |p, category, rating01|
        ((h[p] ||= []) << [category, rating01]) if only_product.nil? or only_product.id == p.id 
      end
      h
    end
    hash_product_2_list_of_category_average_rating01.inject({}) do |h, (p, l_category_rating01)|
        l_category_rating01.group_by(&:first).each do |category, l2|
          ((h[p] ||= {})[category] = (l2.inject(0.0) { |s, (c, r)| s += r }) / l2.size) if (only_product.nil? or only_product.id == p.id) and l2.size
        end if l_category_rating01
      h
    end
  end

  def compute_hash_product_2_average_rating01(hash_product_2_category_average_rating01, only_product)
    hash_product_2_category_average_rating01.inject({}) do |h, (p, hash_category_rating01)|
      if only_product.nil? or only_product.id == p.id
        sum_weight, sum_rating01 = hash_category_rating01.inject([0.0,0.0]) do |(sw, so1), (category, rating01)|
          puts "category=#{category.inspect} rating01=#{rating01}"
          [sw += Review.categories[category], so1 += rating01 * Review.categories[category]]
        end
        h[p] = sum_rating01 / sum_weight
      end
      h
    end
  end

  def compute_elo(comparaisons, all_products)
    elo = Elo.new
    comparaisons.each do |opinion_comparaison|
      # generate_comparaisons yield with [weight, operator_type, :pid1, :pid2]
      # operator_type = "best", "worse", "same"
      opinion_comparaison.for_each_comparaison(all_products) do |weight, operator_type, p1, p2|
        elo.update_elo(p1.id, operator_type, p2.id, Integer(weight))
      end
    end
    elo
  end

  def compute_hash_product_2_average_sub_dimensions(all_products, only_product)
    sub_dimensions = children
    if sub_dimensions.size == 0
      {}
    else
      all_products.inject({}) do |h, product|
        if only_product.nil? or only_product.id == product.id
          sum_weight, sum_nb = sub_dimensions.inject([0.0, 0.0]) do |(s, nb), sub_dimension|
            if x = sub_dimension.get_value_01(product)
              [s + x, nb + 1.0]
            else
              [s, nb]
            end
          end
          (h[product] = sum_weight / sum_nb) if sum_nb > 0.0
        end
        h
      end
    end
  end

  # final aggregation
  def combine_rating_elo_sub_automatic(hash_product_2_average_rating01, elo, hash_product_2_average_sub_dimensions, only_product)

    # rating...
    hash_pid_2_average_mixed = hash_product_2_average_rating01.inject({}) do |h, (p, r)|
      (h[p.id] = {:rating => r}) if only_product.nil? or only_product.id ==p.id
      h
    end

    # elo ...
    elo.for_each_p_elo01 do |product_id, comparaison_rating01|
      ((hash_pid_2_average_mixed[product_id] ||= {})[:comparaison] = comparaison_rating01) if only_product.nil? or only_product.id ==product_id
    end

    # sub dimensions
    hash_product_2_average_sub_dimensions.each do |product, weight_sub_dimension|
      ((hash_pid_2_average_mixed[product.id] ||= {})[:sub_dimensions] = weight_sub_dimension) if only_product.nil? or only_product.id ==product.id    
    end

    # automatic
    # to be written...
    
    # mixin...
    hash_pid_2_average_mixed.inject({}) do |h, (product_id, hash_line_2_value)|
      sum_value, sum_weight = hash_line_2_value.inject([0.0, 0.0]) do |(s1, s2), (line, value)|
        if value
          [s1 + value * Dimension.line_2_weight[line], s2 + Dimension.line_2_weight[line]]
        else
          [s1, s2]
        end
      end
      h[product_id] = sum_value /  sum_weight
      h
    end
  end

  def self.line_2_weight() { :rating => 0.4, :comparaison => 0.4, :sub_dimensions => 0.2 } end

  # measure how a dimension value is safe enough (in terms of number of data)
  def confidence(product)
    unless @confidence and @confidence[product.id]
      (@confidence ||= {})[product.id] = if product.get_value(idurl)
                                            product.opinions.inject(0.0) do |s, opinion|
                                              s += (opinion.dimension_ids.include?(id) ? Review.categories[opinion.category] : 0.0)
                                            end
                                          else
                                            0.0
                                          end
    end
    @confidence[product.id]
  end

  def list_with_ranking(products, ranking_max)
    current_ranking = 0
    previous_rating = nil
    products.collect do |product|
      product_rating = product.get_value(self.idurl)
      current_ranking += 1 if product_rating != previous_rating
      previous_rating = product_rating
      [current_ranking, product]
    end.inject([]) do |l, (ranking, product)|
      if ranking <= ranking_max
        l << ["#{ranking}<sup>#{ranking == 1 ? 'st' : ranking == 2 ? 'nd' : 'rd'}</sup>&nbsp;", product]
      else
        l
      end
    end
  end

  # ---------------------------------------------------------------------




end


