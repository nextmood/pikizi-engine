require 'mongo_mapper'
require 'treetop'
require "products_filter"

# UPDATE Production
# kid = Knowledge.first.id; Dimension.all.each { |d| d.knowledge_id = kid; d.save; }; true
# Opinion.update2_opinion

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Opinion < Root
  
  include MongoMapper::Document


  key :feature_rating_idurl, String # the reference to a feature rating in the model   (rating dimension)
  key :label, String # summary of the opinion
  key :_type, String # class management


  #key :usage, String
  key :usage_ids, Array, :default => []
  many :usages, :in => :usage_ids
  def new_usage() nil end

  key :extract, String
  key :value_oriented, Boolean
  key :validated_by_creator, Boolean, :default => false
  key :category, String
  def weight() Review.categories[category] end
  
  key :review_id, Mongo::ObjectID # the review where this opinion was extracted
  belongs_to :review

  key :user_id, Mongo::ObjectID # the user who recorded this opinion
  belongs_to :user
  key :author_name, String # a name for the source of this opinion  (if user == user.screename)

  key :paragraph_id, Mongo::ObjectID # from which paragraph (if any) this opinion was extracted
  belongs_to :paragraph

  key :product_ids, Array # an Array pg Mongo Object Id defining the products related to this opinion
  many :products, :in => :product_ids

  many :products_filters, :polymorphic => true
  def products_filters_for(name) products_filters.select { |pf| pf.products_selector_dom_name == name } end
  def products_for(name, all_products)
    products_filters_for(name).inject([]) do |l, product_filter|
      product_filter.generate_matching_products(all_products).each { |p| l << p unless l.include?(p) }
      l
    end
  end

  key :dimension_ids, Array, :default => [] # an Array pg Mongo Object Id defining the dimensions related to this opinion  
  def dimensions() Dimension.find(dimension_ids) end

  timestamps!

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

  def self.is_main_document() true end

  def to_html(options={}) "feature_rating_idurl=#{feature_rating_idurl} label, class=#{_type} " end

  def to_html2_prefix
    "#{products_filters_for("referent").collect(&:display_as).join(', ')} "
  end

  def to_html2() " Opinion=#{self.class}???" end
  
  def to_html2_suffix
    #s = dimensions.collect(&:label).join(', ')
    l = []
    l << "<b>$</b>" if value_oriented
    dimensions.each {|d| l << d.label.inspect }
    usages.each { |u| l << u.label.inspect } if usages
    "&nbsp;<i>#{l.join(', ')}</i>"
  end

  def self.generate_xml

  end

  def is_rating?() false end

  def to_xml_bis
    node_opinion = XML::Node.new(self.class.to_s)
    node_opinion['by'] = (user_id ? user.rpx_username : "???")
    node_opinion['dimensions'] = dimensions.collect(&:idurl).join(', ')
    node_opinion['product_selector_1'] = products_filters_for("referent").collect(&:short_label).join(', ')
    usages.collect { |usage| node_opinion << node_usage = XML::Node.new("xxx"); node_usage << usage.label } if usages.size > 0
    (node_opinion << node_extract = XML::Node.new("extract"); node_extract << extract) if extract and extract != ""
    #node_opinion['review_id'] = review_id.to_s
    #node_opinion['paragraph_id'] = paragraph_id.to_s
    node_opinion
  end

  def value_oriented_html() "<b>&nbsp;$</b>" if value_oriented end


  def generate_rating?() nil end
  def generate_comparaison?() nil end


  def self.create_usages
    k = Knowledge.first
    Usage.delete_all
    Opinion.all.each do |opinion|
      opinion.save
    end
    true
  end

  def concern?(product) products_filters_for("referent").any? { |pf| pf.concern?(product) } end

  def content_fck
    unless @content_fck
      s = paragraph.content_without_html
      if extract and extract.size > 0 and i = s.index(extract)
        @content_fck = "#{s[0, i]}<b>#{s[i, extract.size]}</b>#{s[i + extract.size, 10000]}"
      else
        @content_fck = "<b>#{s}</b>"
      end
    end
    @content_fck
  end

  def compute_product_ids_related(all_products)
    update_attributes(:product_ids => compute_product_ids_related_bis(all_products).inject([]) { |l, p| l.include?(p.id) ? l : l << p.id })    
  end

  def compute_product_ids_related_bis(all_products)
    referent = products_filters_for("referent").first
    referent ? referent.generate_matching_products(all_products) : (puts "no referent for opinion=#{self.id}";[])
  end

end


class Rating < Opinion


  key :min_rating, Float, :default => 1
  key :max_rating, Float, :default => 10
  key :rating, Float, :default => 5

  def is_valid?() min_rating and max_rating and rating end

  def to_html(options={}) "#{rating} in [#{min_rating}, #{max_rating}] (#{feature_rating_idurl}#{value_oriented_html})" end

  def to_html2() to_html2_prefix << "<b>rated</b> #{rating} in [#{min_rating}, #{max_rating}]" << to_html2_suffix end

  def rating_01() Root.rule3(rating, min_rating, max_rating) end

  def is_rating?() true end

  def to_xml_bis
    node_opinion = super
    node_opinion['rating'] = rating.to_s
    node_opinion['min'] = min_rating.to_s
    node_opinion['max'] = max_rating.to_s
    node_opinion
  end

  def generate_rating?() true end
  # generate_ratings returns a hash { :pid => [weight, rating_01], ... }
  def for_each_rating(all_products)
    v = rating_01;
    products_for("referent", all_products).each { |p| yield(p, category, v) }
  end


end

class Comparator < Opinion

  key :operator_type, String
  key :predicate, String

  def to_html(options={}) "#{operator_type} than #{predicate} (#{feature_rating_idurl}#{value_oriented_html})" end

  def to_html2
    to_html2_prefix << " <b>is #{operator_type}</b> " << products_filters_for("compare_to").collect(&:display_as).join(', ') << to_html2_suffix
  end
         
  def is_valid?() ["best", "worse", "same"].include?(operator_type) and !Root.is_empty(predicate)  end

  def self.create_from_xml(feature_idurl, operator_type, xml_node)
    self.create(:feature_idurl => feature_idurl,
                               :operator_type => operator_type,
                               :predicate => xml_node["predicate"],
                               :label => xml_node.content.strip)
  end

  def to_xml_bis
    node_opinion = super
    node_opinion['operator'] = operator_type
    node_opinion['product_selector_2'] = products_filters_for("compare_to").collect(&:short_label).join(', ')
    node_opinion
  end




  def generate_comparaison?() true end
  # generate_comparaisons yield with [weight, operator_type, pid1, pid2]
  # operator_type = "best", "worse", "same"
  def for_each_comparaison(all_products)
    ps1 = products_for("referent", all_products)
    ps2 = products_for("compare_to", all_products)
    ps1.each { |p1| ps2.each { |p2| yield(weight, operator_type, p1, p2) unless p1.id == p2.id } }
  end


  def concern?(product)
    super(product) or products_filters_for("compare_to").any? { |pf| pf.concern?(product) }
  end

  def compute_product_ids_related_bis(all_products)
    if compare_to = products_filters_for("compare_to").first
      super(all_products).concat(compare_to.generate_matching_products(all_products))
    else
      puts "no compare_to for opinion #{id}"
      super(all_products)
    end
  end

end


class Tip < Opinion

  key :intensity_symbol, String

  def to_html(options={})
    s = products_filters_for("referent").collect(&:display_as).join(', ') << " is #{intensity_as_label} (#{feature_rating_idurl}#{value_oriented_html})"
    if options[:origin]
      p = paragraph
      s << "&nbsp;<small><a href=\"/reviews/show/#{review.id}?opinion_id=#{self.id}\" >#{review.source}"
      s << "</a></small>"
    end
    s
  end

  def to_html2() to_html2_prefix << "<b>is tipped #{intensity_as_label}</b>" << to_html2_suffix end

  def to_xml_bis
    node_opinion = super
    node_opinion['value'] = intensity_symbol
    node_opinion
  end

  def is_valid?() !Root.is_empty(usage) and !Root.is_empty(intensity) end

  def self.intensities_symbols
    [ ["very good", "very_high" ],
      ["good", "high"],
      ["neutral", "neutral"],
      ["bad", "low"],
      ["very bad", "very_low" ],
      ["mixed", "mixed"] ]
  end

  def self.intensities_value
    { "very_high" => 1.0, "high" => 0.5, "neutral" => 0.0, "mixed" => 0.0, "low" => -0.5, "very_low" => -1.0 }
  end

  def intensity_as_label() x = Tip.intensities_symbols.detect { |l,k| k == intensity_symbol }; x ? x.first : "?????" end

  def intensity() Tip.intensities_value[intensity_symbol] end

  def is_mixed() intensity_symbol == "mixed" end

  def generate_rating?() true end
  
  def for_each_rating(all_products)
    v = Tip.intensities_value[intensity_symbol] / 2 + 0.5
    products_for("referent", all_products).each { |p| yield(p, category, v) }
  end

end

class Ranking < Opinion

  key :order_number, Integer, :default => 1

  def generate_comparaison?() true end

  def to_html2() "among " << products_filters_for("scope_ranking").collect(&:display_as).join(', ') << "; " << to_html2_prefix << "<b>is ranked #{order_number_2_label}</b>" << to_html2_suffix end

  def order_number_2_label() Ranking.order_number_2_label(order_number) end
  def self.order_number_2_label(on) ["first/best", "second", "third"][on - 1] end

  #  scope_ranking
  #referent
  #ranking_first
  #ranking_second

  def for_each_comparaison(all_products)
    ps0 = products_for("scope_ranking", all_products)

    ps1 = products_for("referent", all_products)
    ps2 = products_for("compare_to", all_products)
    ps1.each { |p1| ps2.each { |p2| yield(weight, operator_type, p1, p2) unless p1.id == p2.id } }
  end


  def concern?(product)
    super(product) or products_filters_for("compare_to").any? { |pf| pf.concern?(product) }
  end

  def compute_product_ids_related_bis(all_products)
    if scope_ranking = products_filters_for("scope_ranking").first
      super(all_products).concat(scope_ranking.generate_matching_products(all_products))
    else
      puts "no scope ranking for opiniuon #{id}"
      super(all_products)
    end
  end

end




