require 'mongo_mapper'
require 'treetop'
require "products_filter"

# ==============================================================================
# Opinion (Abstract class)
# an opinion belongs to a paragraph (this is mandatory)
# ==============================================================================

class Opinion < Root
  
  include MongoMapper::Document

  key :label, String # summary of the opinion
  key :_type, String # class management
  key :written_at, Date
  
  # key :usage, String (alson named XXX)
  key :usage_ids, Array, :default => []
  many :usages, :in => :usage_ids
  def new_usage() nil end

  # the natural language sentence(s) on which is created this opinion
  # if none -> the whole paragraph -> if none the whole review
  key :extract, String

  # this opinion is somehow related to a price/value concept
  key :value_oriented, Boolean

  # category of source amazon, expert, etc... (this is the same as the review containing this opinion)
  key :category, String
  def weight() Review.categories[category] end

  # the review to which this opinion belong
  key :review_id, BSON::ObjectID # the review where this opinion was extracted
  belongs_to :review

  # the user/author who recorded this opinion
  key :user_id, BSON::ObjectID
  belongs_to :user
  key :author_name, String # a name for the source of this opinion  (if user == user.screename)

  # from which paragraph this opinion was extracted
  key :paragraph_id, BSON::ObjectID
  belongs_to :paragraph


  # store the product filters
  # all opinions objects have at least a "referent" products_filter
  many :products_filters, :polymorphic => true
  def products_filters_for(name) products_filters.select { |pf| pf.products_selector_dom_name == name } end
  def products_for(name, all_products)
    pids = hash_products_filter_name_2_matching_product_ids[name]
    all_products.select { |p| pids.include?(p.id )}
  end
  def products_filter_names() ["referent"] end
  
  # an Array pg Mongo Object Id defining the products related to this opinion
  key :product_ids, Array
  many :products, :in => :product_ids
  key :hash_products_filter_name_2_matching_product_ids, Hash

  # compute and save the product ids related to this opinion
  def compute_product_ids(all_products)
    among_products = all_products.select do |p|
      d1 = p.release_date
      d2 = self.written_at
      begin
        d1 <= d2
      rescue
        raise "product=#{p.id} #{d1.inspect} and opinion=#{self.id} written_at=#{d2.inspect}"
      end
    end
    # compute and set hash_products_filter_name_2_matching_product_ids first
    new_hash_products_filter_name_2_matching_product_ids = products_filter_names.inject({}) do |h, pf_name|
      set_product_ids = products_filters_for(pf_name).inject(Set.new) do |s, pf|
                            if s.size == 0 or pf.preceding_operator == "or"
                              s.union(pf.compute_matching_product_ids(among_products))
                            elsif pf.preceding_operator == "and"
                              s.intersection(pf.compute_matching_product_ids(among_products))
                            else
                              raise "wrong case... name=#{name} s=#{s.inspect}, product_filter=#{pf.inspect}"
                            end
                        end
      h[pf_name] = set_product_ids.to_a
      h
    end
    # now compute product_ids...
    new_product_ids = new_hash_products_filter_name_2_matching_product_ids.inject(Set.new) do |s, (pf_name, product_ids)|
      s.union(product_ids)
    end.to_a
    update_attributes(:hash_products_filter_name_2_matching_product_ids => new_hash_products_filter_name_2_matching_product_ids,
                      :product_ids => new_product_ids)
  end
  def concern?(product) product_ids.include?(product.id) end


  # the various dimension/rating
  key :dimension_ids, Array, :default => [] # an Array pg Mongo Object Id defining the dimensions related to this opinion  
  def dimensions() Dimension.find(dimension_ids) end

  timestamps!

  def self.related_reviews_for(list_opinions)
    set_review_ids = list_opinions.inject(Set.new) do |s, o| s << o.review_id end
    Review.all(:id => set_review_ids.to_a)  
  end

  def self.related_products_for(list_opinions)
    set_product_ids = list_opinions.inject(Set.new) do |s, o|
      o.hash_products_filter_name_2_matching_product_ids["referent"].each { |pid| s << pid }
    end
    Product.all(:id => set_product_ids.to_a)  
  end

  # -----------------------------------------------------------------
  # state machine

  state_machine :initial => :draft do

    state :draft

    state :to_review

    state :reviewed_ok

    state :reviewed_ko

    state :error 

    event :submit do
      transition all => :to_review
    end

    event :accept do
      transition :to_review => :reviewed_ok
    end

    event :reject do
      transition :to_review => :reviewed_ko
    end

    event :correct do
      transition all => :draft
    end

    event :error do
      transition all => :error
    end

  end

  # extra fields link to the status
  key :errors_explanations, String
  key :censor_code, String
  key :censor_comment, String
  key :censor_date, Date
  key :censor_author_id, BSON::ObjectID

  # to update the status of an opinion
  def update_status(all_products)
    compute_product_ids(all_products)
    if (l = check_errors).size > 0
      update_attributes(:errors_explanations => l.join(', '))
      error!
    else
      update_attributes(:errors_explanations => nil)
      # change the state to to_review
      submit!
    end
  end

  def self.list_states() Opinion.state_machines[:state].states.collect { |s| [s.name.to_s, Opinion.state_datas[s.name.to_s]] } end
  # label of state for UI
  def self.state_datas() { "draft" => {:label => "draft", :color => "lightblue" },
                           "to_review" => {:label => "is waiting to be reviewed", :color => "orange" },
                           "reviewed_ok" => {:label => "is valid (reviewed as OK)", :color => "lightgreen" },
                           "reviewed_ko" => {:label => "is un-valid (reviewed as KO)", :color => "purple" },
                           "error" => {:label => "is in error", :color => "red" } } end

  def state_label() Opinion.state_datas[state.to_s][:label] end
  def state_color() Opinion.state_datas[state.to_s][:color] end

  # -----------------------------------------------------------------
  # html...
  # -----------------------------------------------------------------

  # check and return a list of errors messages for this object
  def check_errors
    l = products_filters_for_should_exist("referent", [])
    l << "you should have one dimension/rating at least" if dimension_ids.size == 0
    l << "you should have less than 6 dimension/rating" if dimension_ids.size > 6
    l
  end

  def products_filters_for_should_exist(name, l)
    pf = products_filters_for(name)
    l << "you should have at least one products filter \"#{name}\"" if pf.size == 0
    l
  end

  def to_html_prefix() products_filters_for_name_to_html("referent") end

  def products_filters_for_name_to_html(name)
    products_filters_for(name).inject([]) { |l, pf| l << ((l.size == 0 ? "" : " <b>#{pf.preceding_operator}</b> " ) << pf.display_as); l }.join('')
  end

  def products_filters_for_name_to_xml(name)
    products_filters_for(name).inject([]) { |l, pf| l << ((l.size == 0 ? "" : " #{pf.preceding_operator} " ) << pf.short_label); l }.join('')
  end

  def to_html() " Opinion=#{self.class}???" end
  
  def to_html_suffix
    #s = dimensions.collect(&:label).join(', ')
    l = []
    l << "<b>$</b>" if value_oriented
    dimensions.each {|d| l << d.label.inspect }
    usages.each { |u| l << u.label.inspect } if usages
    "&nbsp;<i>#{l.join(', ')}</i>"
  end

  def value_oriented_html() "<b>&nbsp;$</b>" if value_oriented end

  # -----------------------------------------------------------------
  # rating aggregation generation
  # -----------------------------------------------------------------

  def generate_rating?() nil end   # does this opinion generate rating (for weighted aggregation)
  def generate_comparaison?() nil end  # does this opinion generate comparaison (for weighted ELO aggregation)


  # -----------------------------------------------------------------
  # xml
  # -----------------------------------------------------------------

  def self.generate_xml() end

  def to_xml_bis
    node_opinion = XML::Node.new(self.class.to_s)
    node_opinion['by'] = (user_id ? user.rpx_username : "??? no_user")
    node_opinion['dimensions'] = dimensions.collect(&:idurl).join(', ')
    node_opinion['product_selector_1'] = products_filters_for_name_to_xml("referent")
    usages.collect { |usage| node_opinion << node_usage = XML::Node.new("xxx"); node_usage << usage.label } if usages.size > 0
    (node_opinion << node_extract = XML::Node.new("extract"); node_extract << extract) if extract and extract != ""
    #node_opinion['review_id'] = review_id.to_s
    #node_opinion['paragraph_id'] = paragraph_id.to_s
    node_opinion
  end

  # -----------------------------------------------------------------
  # processing the form
  # -----------------------------------------------------------------

  def process_attributes(knowledge, params)
    process_attributes_products_selector(knowledge, "referent", params)
    self.dimension_ids = (params[:dimensions] || []).collect { |dimension_id| BSON::ObjectID.from_string(dimension_id) }

    puts ">>>>>>>>>>params[:usages]=>>>>>>>>> #{params[:usages].inspect}"
    params_usages = (params[:usages] || [])
    params_usages = params_usages.collect { |k, v| v } if params_usages.is_a?(Hash)
    puts ">>>>>>>>>>params[:usages]=>>>>>>>>> #{params_usages.inspect}"

    self.usage_ids = params_usages.inject([]) do |l, values|
      #puts ">>>>>>>>>>values=>>>>>>>>> #{values.inspect}"
      usage_label = values ? values[:label].strip : nil
      if usage_label and usage_label.size > 0
        unless existing_usage = Usage.first(:label => usage_label)
          # creating a new usage...
          existing_usage = Usage.create(:label => usage_label, :knowledge_id => knowledge.id)
        end
        l << existing_usage.id
      end
      l
    end
    self.value_oriented = (get_attribute(params, :value_oriented) == "1")       
    self.extract = get_attribute(params, :extract)
  end

  def self.fix_empty_referent
    Opinion.all.each do |opinion|
      if opinion.products_filters_for("referent").size == 0
        opinion.review.products.each do |product_for_review|
          opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => product_for_review.id ).update_labels(product_for_review)
          puts "opinion #{opinion.id} has no referent default adding #{product_for_review.label}"
        end
        opinion.save
      end
    end
    true
  end

  # -----------------------------------------------------------------
  # private
  # -----------------------------------------------------------------
    
  # ---- internal use (should be private)
  def process_attributes_products_selector(knowledge, products_selector_name, params)
    params_pf = get_zozo(params, "products_filter_#{products_selector_name}")
    if params_pf.size > 0
      # remove previous products filters
      products_filters_for(products_selector_name).each(&:destroy)
      # create new products filters
      # puts ">>>>>>>>>>>>>>> params_pf=" <<  params_pf.inspect
      params_pf = params_pf.collect { |k, h| h } if params_pf.is_a?(Hash)
      params_pf.each do |values|
        products_filter = Kernel.const_get(values["_type"]).new
        products_filter.process_attributes(knowledge, products_selector_name, self, values)
        products_filter.save
        self.products_filters << products_filter
        # pp(products_filter, $>, 40)
      end
      true
    end
  end

  def get_zozo(params, prefix)
    puts ">>>>>>>>>>>>>>> params=" <<  params.inspect
    l = params.inject([]) { |l, (param_name, param_value)| param_name.has_prefix(prefix) ? l << param_value : l }
    puts ">>>> after filter=#{l.inspect}"
    l
  end

  def get_attribute(params, attr_symbol) params[self.class.to_s.downcase.to_sym][attr_symbol] end

  # testing a formal grammar parser ... interersting
  def self.parse
    Treetop.load "./app/models/opinion"
    parser = OpinionGrammarParser.new
    [ "iphone is very good",
      "all products are mixed",
      "products with nb pixel of camera > 3mpx are very good" ,
      "hardware of iphone is mixed",
      "droid worse than iphone",
      "droid and nexus are very bad" ,
      "droid and nexus and iphone are same",
      "iphone ranked first",
      "nexus rated 4 between 0 and 5",
      "droid better than all products",
      "camera of iphone and droid worse than products with camera nb pixel > 3mpx and products compatible with carriers att and sprint" ,
      "iphone and similar_to iphone same as products compatible with carriers att or sprint and products with brand apple"
    ].each do |expression|
      if result = parser.parse(expression)
        puts "#{expression.inspect} --> #{result.tom}"
      else
        puts "******* failure  parsing #{expression.inspect}"
      end
    end
    true
  end

end

# ==============================================================================
# Neutral : an opinion to model only dimension  (factual)
# ==============================================================================

class Neutral < Opinion

  def to_html() to_html_prefix << " <b>is neutral</b> " << to_html_suffix end

  def to_xml_bis
    node_opinion = super
    node_opinion
  end

  def process_attributes(knowledge, params)
    super(knowledge, params)
  end

  def self.create_from_neutral_tips
    Tip.all(:intensity_symbol => "neutral").each do |tip_neutral|
      opinion_neutral = Neutral.create( :label => tip_neutral.label,
                                        :written_at => tip_neutral.written_at,
                                        :usage_ids => tip_neutral.usage_ids,
                                        :extract => tip_neutral.extract,
                                        :value_oriented => tip_neutral.value_oriented,
                                        :category => tip_neutral.category,
                                        :review_id => tip_neutral.review_id,
                                        :user_id => tip_neutral.user_id,
                                        :author_name => tip_neutral.author_name,
                                        :paragraph_id => tip_neutral.paragraph_id,
                                        :product_ids => tip_neutral.product_ids,
                                        :dimension_ids => tip_neutral.dimension_ids)
      tip_neutral.products_filters.each { |pf| pf.update_attributes(:opinion_id => opinion_neutral.id) }
      tip_neutral.destroy
    end
  end
end


# ==============================================================================
# Rating : an opinion to model a rating, a note
# ==============================================================================

class Rating < Opinion

  key :min_rating, Float, :default => 1.0
  key :max_rating, Float, :default => 10.0
  key :rating, Float, :default => 5.0

  # check and return a list of errors messages for this object
  def check_errors
    l = super
    if min_rating and max_rating and rating
      l << "ratings are wrongs" unless min_rating < max_rating and rating >= min_rating and rating <= max_rating 
    else
      l << "ratings should be numbers"
    end
    l
  end

  def to_html() to_html_prefix << " <b>rated</b> #{rating} in [#{min_rating}, #{max_rating}]" << to_html_suffix end

  # return a return between 0.0 and 1.0
  def rating_01() Root.rule3(rating, min_rating, max_rating) end

  def to_xml_bis
    node_opinion = super
    node_opinion['rating'] = rating.to_s
    node_opinion['min'] = min_rating.to_s
    node_opinion['max'] = max_rating.to_s
    node_opinion
  end

  # generate_ratings returns a hash { :pid => [weight, rating_01], ... }  
  def generate_rating?() true end
  def for_each_rating(all_products)
    v = rating_01
    products_for("referent", all_products).each { |p| yield(p, category, v) }
  end

  def process_attributes(knowledge, params)
    super(knowledge, params)
    self.min_rating = begin (x = get_attribute(params, :min_rating)) ? Float(x) : nil; rescue nil; end
    self.max_rating = begin (x = get_attribute(params, :max_rating)) ? Float(x) : nil; rescue nil; end
    self.rating = begin (x = get_attribute(params, :rating)) ? Float(x) : nil; rescue nil; end
  end

end

# ==============================================================================
# Comparator : an opinion to model a comparaison between 2 products or group of products
# ==============================================================================

class Comparator < Opinion

  key :operator_type, String

  def to_html
    to_html_prefix << " <b>is #{Comparator.hash_operator_type_2_label[operator_type]}</b> " << products_filters_for_name_to_html("compare_to") << to_html_suffix
  end
         
  def check_errors
    l = super
    l << "wrong operator type #{operator_type.inspect}" unless Comparator.hash_operator_type_2_label.any? { |k, v| k == operator_type }
    products_filters_for_should_exist("compare_to", l)
  end

  def self.hash_operator_type_2_label() {"better" => "better than", "worse" => "worse than", "same" => "same as"} end

  def to_xml_bis
    node_opinion = super
    node_opinion['operator'] = operator_type
    node_opinion['product_selector_2'] = products_filters_for_name_to_xml("compare_to")
    node_opinion
  end

  # generate_comparaisons yield with [weight, operator_type, pid1, pid2]
  def generate_comparaison?() true end
  def for_each_comparaison(all_products)
    ps1 = products_for("referent", all_products)
    ps2 = products_for("compare_to", all_products)
    ps1.each { |p1| ps2.each { |p2| yield(weight, operator_type, p1, p2) unless p1.id == p2.id } }
  end

  def products_filter_names() super() << "compare_to" end

  def process_attributes(knowledge, params)
    super(knowledge, params)
    process_attributes_products_selector(knowledge, "compare_to", params)
    self.operator_type = get_attribute(params, :operator_type)
  end

end

# ==============================================================================
# Tip : an opinion to model a tip, a kind of standardized rating
# ==============================================================================

class Tip < Opinion

  key :intensity_symbol, String

  def to_html() to_html_prefix << " <b>is tipped #{intensity_as_label}</b> " << to_html_suffix end

  def to_xml_bis
    node_opinion = super
    node_opinion['value'] = intensity_symbol
    node_opinion
  end

  def check_errors
    l = super
    l << "wrong intensity #{intensity_symbol}" unless Tip.intensities_symbols.any? { |k, v| intensity_symbol == v }
    l
  end

  def self.intensities_symbols
    [ ["very good", "very_high" ],
      ["good", "high"],
      ["mixed", "mixed"],
      ["bad", "low"],
      ["very bad", "very_low" ]]
  end

  def self.intensities_value
    { "very_high" => 1.0, "high" => 0.5, "mixed" => 0.0, "low" => -0.5, "very_low" => -1.0 }
  end

  def intensity_as_label() x = Tip.intensities_symbols.detect { |l,k| k == intensity_symbol }; x ? x.first : "??? wrong intensity_symbol" end

  def intensity() Tip.intensities_value[intensity_symbol] end

  def generate_rating?() true end
  def for_each_rating(all_products)
    v = Tip.intensities_value[intensity_symbol] / 2 + 0.5
    products_for("referent", all_products).each { |p| yield(p, category, v) }
  end

  def process_attributes(knowledge, params)
    super(knowledge, params)
    self.intensity_symbol = get_attribute(params, :intensity_symbol)
  end

end

# ==============================================================================
# Ranking : an opinion to model a Ranking (first, second, third) in a group o products
# ==============================================================================

class Ranking < Opinion

  key :order_number, Integer, :default => 1  # first, 2nd or third
  def order_number_2_label() Ranking.order_number_2_label(order_number) end
  def self.order_number_2_label(on) ["first/best", "second", "third"][on - 1] end

  def to_html() "among " << products_filters_for_name_to_html("scope_ranking") << "; " << to_html_prefix << "<b>is ranked #{order_number_2_label}</b>" << to_html_suffix end

  def check_errors
    l = super
    l << "wrong order number #{order_number.inspect}" unless order_number and order_number >= 1 and order_number <= 3
    l = products_filters_for_should_exist("scope_ranking", l)
    l = products_filters_for_should_exist("ranking_first", l) if order_number > 1
    l = products_filters_for_should_exist("ranking_second", l) if order_number > 2
    l
  end

  def generate_comparaison?() true end
  def for_each_comparaison(all_products, &block)
    ps0 = products_for("scope_ranking", all_products)  #  scope_ranking
    ps1 = products_for("referent", all_products)     # referent
    ps2 = products_for("ranking_first", all_products)  if order_number > 1 # ranking_first (if 2nd or third)
    ps3 = products_for("ranking_second", all_products) if order_number > 2 # ranking_third  (if 3rd)

    case order_number
      when 1
        for_each_comparaison_better(ps1, ps0, [], block)
      when 2
        for_each_comparaison_better(ps2, ps0, [], block)
        for_each_comparaison_better(ps1, ps0, [ps2], block)
      when 3
        for_each_comparaison_better(ps2, ps0, [], block)
        for_each_comparaison_better(ps3, ps0, [ps2], block)
        for_each_comparaison_better(ps1, ps0, [ps2, ps3], block)
    end

  end
  def for_each_comparaison_better(ps1, ps2, except, block)
    except_ids = except.inject([]) { |l, ps| ps.each { |p| l << p.id unless l.include?(p.id) }; l }
    ps1.each { |p1| ps2.each { |p2| block.call(weight, "better", p1, p2) unless p1.id == p2.id or except_ids.include?(p2.id) } }
  end

  def products_filter_names
    l = super() << "scope_ranking"
    l << "ranking_first" if order_number > 1
    l << "ranking_second" if order_number > 2
    l
  end

  def process_attributes(knowledge, params)
    super(knowledge, params)
    self.order_number = begin (x = get_attribute(params, :order_number) and x.size > 0) ? Integer(x) : nil; rescue nil; end
    process_attributes_products_selector(knowledge, "scope_ranking", params)
    process_attributes_products_selector(knowledge, "ranking_first", params) if order_number and order_number > 1
    process_attributes_products_selector(knowledge, "ranking_second", params) if order_number and order_number > 2
  end

end



