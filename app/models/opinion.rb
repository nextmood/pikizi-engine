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

  def to_html(options={}) "feature_rating_idurl=#{feature_rating_idurl} label=#{label}, class=#{_type} " end

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
    node_opinion['dimensions'] = dimensions.collect(&:idurl).join(', ')
    node_opinion['product_selector_1'] = products_filters_for("referent").collect(&:short_label).join(', ')
    usages.collect { |usage| node_opinion << node_usage = XML::Node.new("xxx"); node_usage << usage.label } if usages.size > 0
    (node_opinion << node_extract = XML::Node.new("extract"); node_extract << extract) if extract and extract != ""
    #node_opinion['review_id'] = review_id.to_s
    #node_opinion['paragraph_id'] = paragraph_id.to_s
    node_opinion
  end

  def value_oriented_html() "<b>&nbsp;$</b>" if value_oriented end


  def self.product_ids_origin(knowledge, review)
    l_select = review.products.collect { |p| [p.label, p.id] }
    header = []
    header << [l_select.collect(&:first).join(' & '), l_select.collect(&:last).join('-')] if l_select.size > 1

    knowledge.products.each do |p|
      l_select << [p.label, p.id] unless l_select.any? { |l,i| i == p.id }  
    end
    header.concat(l_select)
    header
  end



  # generate the product filters for field referent
  # ensure dimensions_ids correct and usage_id too
  def generate_products_filters(knowledge)
    ld = []
    fidurl = feature_rating_idurl
    if fidurl == "functionality & performance"
      fidurl = "functionality_performance_rating"
      update_attribute(:feature_rating_idurl => fidurl)
    end
    if d = Dimension.first(:idurl => fidurl)
      ld << d
    else
      puts "opinion= #{id} no dimension #{fidurl.inspect}"
    end
    self.dimension_ids = ld.collect(&:id)

    ls = []
    if usage and usage != ""
      usage_o = Usage.first(:label => usage)
      usage_o ||= Usage.create(:label => usage, :knowledge_id => knowledge.id)
      ls << usage_o
    end
    self.usages = ls

    lpf = []
    products_for_opinion = products
    products_for_opinion = review.products if products_for_opinion.size == 0
    products_for_opinion.collect do |p|
      lpf << ProductByLabel.create(:opinion_id => id, :products_selector_dom_name => "referent", :product_id => p.id )
    end
    self.products_filters = lpf

  end

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

end


class Rating < Opinion


  key :min_rating, Float, :default => 1
  key :max_rating, Float, :default => 5
  key :rating, Float, :default => 3

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


  def generate_products_filters(knowledge)
    super(knowledge) # generate the product filters for field referent

    # generate the product filters for field compare_to
    if (predicate =~ /productIs\(:any => \["[a-z_0-9A-Z\-]*"\]\)/ and pidurl = predicate.find_between("\"", "\"").first) or
       (predicate =~ /productIs\(:[a-z_0-9A-Z\-]*\)/ and pidurl = predicate.find_between(":", ")").first)
      # translate a product...
      begin
        if ["all_products"].include?(pidurl)
          products_filters << ProductByShortcut.create(:opinion_id => id, :products_selector_dom_name => "compare_to", :display_as => pidurl, :shortcut_selector => pidurl )
        else
          product = Product.first(:idurl => pidurl)
          product ||= Product.find(pidurl)
          products_filters << ProductByLabel.create(:opinion_id => id, :products_selector_dom_name => "compare_to", :product_id => product.id ) if product
        end
      rescue
        product = nil
      end
      puts "no definition for predicate=#{predicate} and pidurl=#{pidurl}" unless product or pidurl == "all_products"

    elsif predicate =~ /featureIs\(:[a-z_0-9A-Z\-]*, :any => \["[a-z_0-9A-Z\-]*"(, "[a-z_0-9A-Z\-]*")*\]\)/
      # translate a feature is...
      sidurl = predicate.find_between(":", ",").first
      tag_idurls_ok = predicate.find_between("\"", "\"")
      if specification = Specification.first(:idurl => sidurl)
        hash_tag_idurl_tag = specification.tags.inject({}) { |h,t| h[t.idurl] = t; h }
        if tag_idurls_ok.all? {|tidurl| hash_tag_idurl_tag[tidurl] }
          products_filters << ProductsBySpec.create(:opinion_id => id, :products_selector_dom_name => "compare_to",
              :display_as => "#{specification.label} = " << tag_idurls_ok.collect { |t_ok_idurl| hash_tag_idurl_tag[t_ok_idurl].label }.join(' or '),
              :specification_id => specification.id, :expressions => tag_idurls_ok )
        else
          puts "no tags for specification #{sidurl}=(#{}) in predicate #{predicate}"
        end
      else
        puts "no specification #{sidurl} in predicate #{predicate}"
      end
    else
      raise "error unmatching predicate #{predicate}"
    end

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


end




