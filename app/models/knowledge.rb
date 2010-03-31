require 'xml'
require 'mongo_mapper'
require 'specification'
#require 'graphviz'

class Knowledge < Root

  include MongoMapper::Document

  key :idurl, String # unique url
  key :label, String 
  key :categories_map, Array # [[key_category_1, label_category_1], ... [key_category_n, label_category_n]]

  key :dimension_root, Dimension
  many :dimensions, :polymorphic => true

  many :specifications, :polymorphic => true
  def specifications_root() specifications.select { |s| s.parent_id.nil? } end
  
  many :features, :polymorphic => true   # first level features

  key :question_idurls, Array
  def questions() @questions ||= Question.load_db(question_idurls)  end
  def questions_sorted_by_desc_discrimination(pidurls, user=nil)
    questions.sort { |q1, q2| q2.discrimination(user, pidurls) <=> q1.discrimination(user, pidurls) }
  end

  #key :product_idurls, Array
  #def products() @products ||= Product.load_db(product_idurls) end
  many :products

  key :quizze_idurls, Array
  def quizzes() @quizzes ||= Quizze.load_db(quizze_idurls) end

  key :cache_nb_products, Integer
  key :cache_nb_questions, Integer
  key :cache_nb_quizzes, Integer
  key :cache_nb_reviews, Integer

  many :usages

  timestamps!

  def self.is_main_document() true end

  def each_feature(&block) features.each { |sub_feature| sub_feature.each_feature(&block) }; nil end
  def each_feature_rating(&block) each_feature { |feature| block.call(feature) if feature.is_a?(FeatureRating) } ;nil end
  def feature_ratings() l = []; each_feature_rating { |o| l << o }; l end

  def each_feature_collect(&block) l = []; each_feature { |feature| l << block.call(feature) }; l end
  def features_all() each_feature_collect { |o| o } end
  def nb_features() nb = 0; each_feature { |f| nb += 1 }; nb end

  def self.all_key_label(options={})
    @@all_key_label ||= Knowledge.all.collect {|k| [k.idurl, k.label] }
    if options[:only] == :idurl
      @@all_key_label.collect { |idurl, label| idurl }
    elsif options[:only] == :label
      @@all_key_label.collect { |idurl, label| label }
    else
      @@all_key_label
    end
  end


  def link_back() features.each { |sub_feature| sub_feature.link_back(self) }; self end

  # read and create a domain (knowledge + questions, products and quizzes in the database)
  # this could be called by a rast task
  # return the newly created knowledge
  def self.initialize_from_xml(knowledge_idurl)
    #begin
      domain_directory = "public/domains/#{knowledge_idurl}"
      xml_node = open_xml_bis("#{domain_directory}/knowledge/knowledge.xml", knowledge_idurl)

      knowledge = super(xml_node)
      knowledge.read_xml_list(xml_node, "Feature", :container_tag => 'sub_features')
      knowledge.link_back
      knowledge.save

      knowledge.product_idurls = read_children_xml(knowledge, domain_directory, "Product")
      knowledge.question_idurls = read_children_xml(knowledge, domain_directory, "Question")
      knowledge.quizze_idurls = read_children_xml(knowledge, domain_directory, "Quizze")
      knowledge.link_back
      knowledge.save

      knowledge
    #rescue Exception => e
    #  puts "Error #{e.message}"
    #   puts "Error #{e.backtrace.inspect}"
    #  nil
    #end
  end

  # return a list of sub idurl
  def self.read_children_xml(knowledge, domain_directory, tag)
    tag_class = Kernel.const_get(tag)
    tag_downcase = tag.downcase
    tag_downcase_plural = "#{tag_downcase}s"
    get_entries("#{domain_directory}/#{tag_downcase_plural}").inject([]) do |l, sub_idurl|
      sub_node = open_xml(domain_directory, sub_idurl, tag)
      tag_class.initialize_from_xml(knowledge, sub_node)
      l << sub_idurl
    end
  end

  def self.open_xml(domain_directory, idurl, tag)
    tag_downcase = tag.downcase
    tag_downcase_plural = "#{tag_downcase}s"
    open_xml_bis("#{domain_directory}/#{tag_downcase_plural}/#{idurl}/#{tag_downcase}.xml", idurl)
  end

  def self.open_xml_bis(filename, idurl)
    raise "I can't find: #{filename}" unless File.exist?(filename)
    xml_node = XML::Document.file(filename).root
    xml_node['idurl'] = idurl
    xml_node
  end

  def get_price_min_html(product) get_price_min_max_html(product, :min) end
  def get_price_min_max_html(product, mode = :minmax)
    f_prices = ["unsubsidized_price", "subsidized_price", "special_carrier_promotion", "amazon_price", "bestbuy_price", "radioshack_price"]
    prices = f_prices.collect { |feature_name| get_feature_by_idurl(feature_name).get_value(product) }.compact
    if prices.size > 0
      price_min = prices.min
      price_max = prices.max
      if mode == :minmax and price_min != price_max
        "$ #{'%.2f' % price_min} to $ #{'%.2f' % price_max}"
      else
        "$ #{'%.2f' % price_min}"
      end
    else
      "n/a"
    end
  end


  # return a list of sub idurl
  def self.write_children_xml(knowledge, object_idurls, domain_directory, tag)
    tag_class = Kernel.const_get(tag)
    tag_downcase = tag.downcase
    tag_downcase_plural = "#{tag_downcase}s"

    object_idurls.each do |object_idurl|
      sub_doc = XML::Document.new
      new_object = tag_class.load_db(object_idurl)
      new_object.generate_xml(knowledge, sub_doc)
      domain_tag_directory = "#{domain_directory}/#{tag_downcase_plural}/#{object_idurl}"
      system("mkdir #{domain_tag_directory}") unless File.exist?(domain_tag_directory)
      sub_doc.save("#{domain_tag_directory}/#{tag_downcase}.xml")
    end

  end

  # this entry will update the whole xml directories/files
  def generate_xml
    domain_directory = "public/domains/#{idurl}"
    doc = XML::Document.new
    node_knowledge = super(doc)
    Root.write_xml_list(node_knowledge, features, 'sub_features')
    doc.save("#{domain_directory}/knowledge/knowledge.xml")

    Knowledge.write_children_xml(self, question_idurls, domain_directory, "Question")
    Knowledge.write_children_xml(self, product_idurls, domain_directory, "Product")
    Knowledge.write_children_xml(self, quizze_idurls, domain_directory, "Quizze")
  end

  def self.to_xml()
    doc = XML::Document.new
    doc.root = node_knowledges = XML::Node.new("knowledges")
    Knowledge.all.each { |knowledge| node_knowledges << knowledge.to_xml_bis }
    doc.to_s(:indent => true)    
  end

  def to_xml_bis
    node_knowledge = XML::Node.new("Knowledge")
    node_knowledge['idurl'] = idurl
    node_knowledge['label'] = label

    # products
    node_knowledge << node_products = XML::Node.new("products")
    products.each do |product|
      node_products << node_product = XML::Node.new(product.class.to_s)
      node_product['idurl'] = product.idurl
    end

    # questions
    node_knowledge << node_questions = XML::Node.new("questions")
    questions.each do |question|
      node_questions << node_question = XML::Node.new(question.class.to_s)
      node_question['idurl'] = question.idurl
    end

    # quizzes
    node_knowledge << node_quizzes = XML::Node.new("quizzes")
    quizzes.each do |quizze|
      node_quizzes << node_quizze = XML::Node.new(quizze.class.to_s)
      node_quizze['idurl'] = quizze.idurl
    end

    # features
    node_knowledge << node_features = XML::Node.new("features")
    features.each do |feature|
      node_features << node_feature = feature.generate_xml(node_features)
    end
    
    node_knowledge
  end


  def generate_product_template(product=nil)
    doc = XML::Document.new
    doc.root =  (top_node = XML::Node.new("Product"))
    top_node['label'] = product ? product.label : "Label..."
    features.each { |feature| feature.generate_product_template(top_node, 0, product)  }
    path = "public/domains/#{idurl}"
    if product
      path = "#{path}/products/#{product.idurl}"
      system("mv #{path}/product.xml #{path}/product_ph.xml")
      doc.save("#{path}/product.xml")
    else
      doc.save("#{path}/knowledge/product_template.xml")
    end
  end

  def generate_reviews_template
    raise "ne pas lancer"
    doc = XML::Document.new
    doc.root =  (top_node = XML::Node.new("Review"))
    top_node['author'] = "ph"
    top_node['product_idurl'] = "a product idurl"
    top_node['date'] = FeatureDate.date2xml(Time.now)

    each_feature_rating do |feature|
      top_node << (node_feature_opinion = XML::Node.new("FeatureOpinion"))
      node_feature_opinion["idurl"] = feature.idurl
      node_feature_opinion << XML::Node.new_comment("<tip usage=\"take picture at night\" intensity=\"pro\" confidence=\"1.0\" >...</Tip>")
      node_feature_opinion << XML::Node.new_comment("<better_than predicate=\"\" />")
      node_feature_opinion << XML::Node.new_comment("<same_as predicate=\"\" />")
      node_feature_opinion << XML::Node.new_comment("<worse_than predicate=\"\" />")
      node_feature_opinion << XML::Node.new_comment("<rated min_rating=\"0\" max_rating=\"5\">3</Rated>")
      node_feature_opinion << (node_rated = XML::Node.new("Rated"))
      node_rated["min_rating"] = feature.min_rating.to_s
      node_rated["max_rating"] = feature.max_rating.to_s
      node_rated << XML::Node.new_comment("a value")
    end
    path = "public/domains/#{idurl}"
    doc.save("#{path}/reviews/review_template.xml")
  end

  def compute_counters
    nb_products(true)
    nb_questions(true)
    nb_quizzes(true)
    nb_reviews(true)
    save
  end

  # return the number of products handled by this model
  def nb_products(reset_cache=false) default_counter(reset_cache, "cache_nb_products") { products.size } end

  # return the number of questions handled by this model
  def nb_questions(reset_cache=false) default_counter(reset_cache, "cache_nb_questions") { questions.size } end

  # sort the questions by criterions
  def questions_sorted(products, user) Question.sort_by_discrimination(questions, products.collect(&:idurl), user) end

  # return the number of questions handled by this model
  def nb_quizzes(reset_cache=false) default_counter(reset_cache, "cache_nb_quizzes") { quizzes.size } end

  # return the number of reviews handled by this model
  def nb_reviews(reset_cache=false) default_counter(reset_cache, "cache_nb_reviews") { products.inject(0) { |s,product| s + product.reviews.size } } end

  # cancel the recommendations generated by a previous answer
  def cancel_recommendations(question, last_answer, quizze_instance, products)
    raise "i don't get it..."
    propagate_recommendations(question, last_answer, quizze_instance.hash_pidurl_affinity, products, true)
  end

  # propagate the recommendations associated with the choices_ok
  # update hash_pidurl_affinity ( a hash table between a product-idurl and and a user affinity)
  def propagate_recommendations(question, answer, hash_pidurl_affinity, products, reverse_mode)
    puts "filtering not implemented yet" if question.is_filter
    question.delta_weight(answer).each do |product_idurl, weight|
      hash_pidurl_affinity[product_idurl].add(weight * (reverse_mode ? -1.0 : 1.0), question.weight)
    end
  end

  # return a new affinity list
  def trigger_recommendations(quizze_instance, question, products, choices_ok, simulation)
    choice_idurls_ok = choices_ok.collect(&:idurl)
    answer = quizze_instance.record_answer(self.idurl, question.idurl, choice_idurls_ok)
    hash_pidurl_affinity = quizze_instance.hash_pidurl_affinity
    hash_pidurl_affinity = hash_pidurl_affinity.inject({}) { |h, (pidurl, a)| h[pidurl] = a.clone } if simulation
    propagate_recommendations(question, answer, hash_pidurl_affinity, products, false)
    quizze_instance.cancel_answer(answer) if simulation
    hash_pidurl_affinity
  end

  def get_product_by_idurl(idurl)
    @hash_idurl_product ||= products.inject({}) { |h, p| ensure_unique(h, p) }
    @hash_idurl_product[idurl]
  end

  def get_question_by_idurl(idurl)
    @hash_idurl_question ||= questions.inject({}) { |h, q| ensure_unique(h, q) }
    @hash_idurl_question[idurl]
  end

  def get_feature_by_idurl(idurl)
    @hash_idurl_feature ||= features_all.inject({}) { |h, f| ensure_unique(h, f) }
    @hash_idurl_feature[idurl]
  end


  def ensure_unique(h, o)
    raise "OUPS more than one idurl=#{o.idurl}" if h[o.idurl]
    h[o.idurl] = o; h
  end
  # --------- Matrix Html ----------------------------------------------------------------

  def compute_dom_id()
    features.each_with_index { |feature, index| feature.compute_dom_id("thematrix_#{index}") }
  end
  # ---------------------------------------------------------------------------------------

  def clean_url(url, product)
    if url.has_prefix("http") or url.has_prefix("/")
      url
    else
      # local url
      "/domains/#{idurl}/products/#{product.idurl}/#{url}"
    end
  end

  def default_counter(reset_cache, keyname)
    if reset_cache or self.send(keyname).nil?
      self.send("#{keyname}=", yield)
    end
    self.send(keyname)
  end


end


# =======================================================================================
# Describe a hierarchy of features
# =======================================================================================

class Feature < Root
  # abstract class

  include MongoMapper::EmbeddedDocument

  key :idurl, String # unique url

  key :label, String # text
  key :is_optional, Boolean, :default => false
  key :no_specification, Boolean, :default => false

  many :features, :polymorphic => true # sub features


  attr_accessor :object_parent, :dom_id

  def create_specification(knowledge_id, parent_id=nil)
    specification_attributes = attributes.clone
    if dimension_class = case specification_attributes.delete("_type")
        when "FeatureTags" then SpecificationTags
        when "FeatureNumeric" then SpecificationNumeric
        when "FeatureDate" then SpecificationDate
        when "FeatureInterval" then SpecificationInterval
        when "FeatureHeader" then SpecificationHeader
        when "FeatureCondition" then SpecificationCondition
        else nil
      end
      specification_attributes.delete("features")
      specification_attributes.delete("_id")
      specification_attributes.delete("_type")
      specification_attributes["parent_id"] = parent_id
      specification_attributes["knowledge_id"] = knowledge_id
      #puts "creating specification=" << specification_attributes.inspect
      specification = dimension_class.create(specification_attributes)
      puts "creating specification #{idurl} class=#{specification.class}"
      features.each {|sub_feature| sub_feature.create_specification(knowledge_id, specification.id) }
    else
      puts "#{self.class} #{idurl} is not a specification"
    end

  end

  def compute_dom_id(dom_id)
    self.dom_id = dom_id
    features.each_with_index { |sub_feature, index| sub_feature.compute_dom_id("#{dom_id}_#{index}") }
  end

  def link_back(object_parent)
    self.object_parent = object_parent
    features.each { |sub_feature| sub_feature.link_back(self) }
  end

  def knowledge() object_parent.is_a?(Knowledge) ? object_parent : object_parent.knowledge end

  # return nil for first level
  def feature_parent() object_parent.is_a?(Knowledge) ? nil : object_parent end


  def is_valid_value?(value) false end

  def is_root?() feature_parent.nil? end

  def has_sub_features() features.size > 0 end

  def label_full() is_root? ? label : "#{feature_parent.label_full}/#{label}" end

  def label_select_tag(rec=nil)
    if rec
      is_root? ? "" : "...#{feature_parent.label_select_tag(true)}"
    else
      "#{label_select_tag(true)}#{label}"
    end
  end

  def self.initialize_from_xml(xml_node)
    feature = super(xml_node)
    feature.is_optional = xml_node['is_optional']
    feature.no_specification = xml_node['no-spec'] ? true : false
    feature.read_xml_list(xml_node, "Feature", :container_tag => 'sub_features')
    feature
  end

  def generate_xml(top_node)
    node_feature = super(top_node)
    node_feature['is_optional'] = "true" if is_optional
    node_feature['no-spec'] = "true" if no_specification
    Root.write_xml_list(node_feature, features, 'sub_features')
    node_feature
  end

  def generate_product_template(top_node, depth, product)
    tag_name = self.class.to_s

    if tag_name == "FeatureHeader"
      tabulation = "    " * (depth + 1)
      top_node << XML::Node.new_comment("#{tabulation}BEGIN #{label} ")
      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
      top_node << XML::Node.new_comment("#{tabulation}END #{label} ")
    elsif tag_name == "FeatureRating"
      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
    else
      tabulation = "    " * depth
      #top_node << XML::Node.new_comment("#{tabulation}#{tag_name} #{label} ")
      top_node << (xml_node = XML::Node.new("Value"))
      xml_node['idurl'] = idurl
      if product and value = product.get_value(idurl)
        xml_node << value2xml(value)
      end
      xml_node << XML::Node.new_comment("#{tabulation}#{product_template_comment()} ")

      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
    end

    top_node
  end
  def product_template_comment() raise "no comment for #{self.class}  " end

  # ---------------------------------------------------------------------
  # to display the matrix
  def get_value_html(product) get_value(product) end

  # this is included in a form
  def get_value_edit_html(product)
    "<div class=\"field\">
        <input type='text' name='feature_#{idurl}' value='#{get_value(product) || ""}' />
     </div>"
  end

  def get_feature_html() "<span title=\"feature #{self.class} idurl=#{idurl} level=#{level}\" >#{label}</span>#{feature_html_suffix}" end
  def feature_html_suffix()
    "<span style=\"margin-left:5px;\" title=\"rating feature\" >*</span>" unless is_optional
  end
  # this is included in a form
  def get_feature_edit_html()
    "<div class=\"field\" title=\"edit feature #{self.class}\">
        <div style='font-weight:normal; font-size:90%;'>#{self.class} : #{idurl}</div>
        <div>mandatory<input type='checkbox' #{'checked' unless is_optional}/></div>
        <div><span>label<span><input type='text' value='#{label}' /></div>
     <div>"
  end

  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) content_string.strip end
  def value2xml(value) value.to_s end

  def color_from_status(product)
    if is_relevant(product) == false
      "gray"
    elsif get_value(product)
      "lightblue"
    else
      is_optional ? "white" : "red"
    end
  end

  # this is related to feature condition
  def is_relevant(product)
    if is_a?(FeatureCondition)
      (value = get_value(product)).nil? or value
    else
      feature_parent ? feature_parent.is_relevant(product) : true
    end
  end

  # this is related to display the specification
  def should_display?(product) !no_specification and (feature_parent ? feature_parent.should_display?(product) : true) end



  # the depth level of a feature
  def level() feature_parent ? 1 + feature_parent.level() : 1 end

  # ---------------------------------------------------------------------

  def each_feature(&block)
    block.call(self)
    features.each do |sub_feature|
      raise "feature= #{self.inspect}" if sub_feature.is_a?(Knowledge)
      sub_feature.each_feature(&block)
    end
    nil
  end


  # return the  FeatureValue(s) for a product, nil if no value (==empty)
  def get_value(product) product.get_value(idurl) end
  def get_value_01(product) raise "error" end

 # define the distance between  2 products for this feature
  def distance(product1, product2)
    begin
      distance_metric(product1, product2)
    rescue
      "ERR"
    end
  end

  def distance_metric(product1, product2) "Undef #{get_value(product1).inspect}" end

#  def distance_graph(products)
#    g = GraphViz.new( :G, :type => :graph, :use => :dot, :path => "/usr/local/bin/" )
#
#    # adding nodes....
#    products.each { |p| g.add_node(p.idurl) }
#
#    # adding distance
#    products.each do |p1|
#      products.each do |p2|
#        if p1.idurl > p2.idurl
#          g.add_edge(g.get_node(p1.idurl), g.get_node(p2.idurl), :len => distance(p1, p2))
#        end
#      end
#    end
#    # Generate output image
#    g.output( :png => "/public/images/graphviz/distance.png" )
#  end

  #mode is either :comparator or :related
  def is_compatible_grammar(mode) false end


  def idurl_h()
    feature_parent ? "#{feature_parent.idurl_h}/#{idurl}" : idurl   
  end

end



# define a list of tags (exclusive or multiple)
# value is a list of tags ok
class FeatureTags < Feature

  key :is_exclusive, Boolean

  many :tags

  def self.initialize_from_xml(xml_node)
    feature_tags = super(xml_node)
    feature_tags.is_exclusive = (xml_node['is_exclusive'] == "true" ? true : false)
    feature_tags.read_xml_list(xml_node, "Tag", :container_tag => 'tags')
    feature_tags
  end

  def generate_xml(top_node)
    node_feature_tag = super(top_node)
    node_feature_tag['is_exclusive'] = is_exclusive.to_s
    Root.write_xml_list(node_feature_tag, tags, 'tags')
    node_feature_tag
  end

  def product_template_comment() "#{is_exclusive ? 'ONE tag' : 'MANY tags'} among: #{tags.collect(&:idurl).join('  ')}" end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array of tag.idurl

  # value 0 for 0 tags selected
  # value 1 for all tags selected
  # the order is also taken into acount
  def get_value_01(product)
    Root.rule3(get_value(product).size.to_f, 0.0, tags.size.to_f)
  end

  def get_value_html(product)
    if idurls_ok = get_value(product)
      tags.select { |t| idurls_ok.include?(t.idurl) }.collect {|t| "#{t.label}" }.join(', ')
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    type_button = is_exclusive ? 'radio' : 'checkbox'
    tag_idurls_ok = get_value(product) || []
    tags.inject("") do |s, tag|
      s << "<input type='#{type_button}' name='feature_#{tag.idurl}' title='idurl=#{tag.idurl}' value='#{tag.idurl}' #{ tag_idurls_ok.include?(tag.idurl) ? 'checked' : nil} />#{tag.label}"
    end
  end

  def get_feature_html() "<span title=\"#{tags.collect(&:label).join(', ')}, level=#{level}\">#{label}</span>#{feature_html_suffix}" end

  # this is included in a form
  def get_feature_edit_html()
    super() << "<div class=\"field\">
                   <span>exclusive tag?</span>
                    <input type='checkbox' name='is_exclusive' value='1' #{ is_exclusive ? 'checked' : nil} />
                   <br/>
                   <input type='text' style=\"width:95%;\" value='" << tags.collect(&:label).join(', ') << "' />
                </div>"
  end

  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string)
    content_string = content_string.strip
    has_space = content_string.include?(' ')
    has_comma = content_string.include?(',')
    raise "error" if has_space and has_comma
    if has_space
      tag_idurls = content_string.split(' ')
    elsif has_comma
      tag_idurls = content_string.split(',')
    else
      tag_idurls = [content_string]
    end
    tag_idurls.each(&:strip!)
    tag_idurls
  end
  def value2xml(value) value.join(', ') end

  # ---------------------------------------------------------------------


  # return 2 arrays of feature_tag_idurls used as minima, maxima in among products
  # minima = intersection of all feature tag idurls
  # maxima = union of all feature tag idurls
  def range(among_products)
    all_tags_idurls = tags.collect(&:idurl)
    min, max = among_products.inject([Set.new(all_tags_idurls), Set.new]) do |sets, product|
      intersection, union = sets
      product_tag_idurls = product.product.get_value(idurl)
      product_tag_idurls ? [i.intersection(product_tag_idurls), u.merge(product_tag_idurls)] : [intersection, union]
    end
    max.size > min.size ? [min, max] : [[], all_tags_idurls]
  end

  #mode is either :comparator or :related
  def is_compatible_grammar(mode) true end

  # this function is overloaded by type
  # and define the kind of filtering operation that can be apply on the value
  # of this field
  def operator_filtering(feature)
    if feature.is_a?(FeatureTags)
      if is_exclusive
        [ { :key => "is_either", :gui => select_simple(feature.tags) },
          { :key => "is_not", :gui => select_multiple(feature.tags) } ]
      else
        [ { :key => "include_or", :gui => select_simple(feature.tags) },
          { :key => "are_neither", :gui => select_multiple(feature.tags) } ]
      end
    elsif feature.is_a?(FeatureNumeric)

    end
  end



end

# define a rating value
# aggregations objects are attached for each featureRating/Product
# value is an Integer
class FeatureRating < Feature

  key :min_rating, Integer, :default => 1
  key :max_rating, Integer, :default => 5
  key :user_category, String, :default => 'user'

  def self.initialize_from_xml(xml_node)
    feature_rating = super(xml_node)
    feature_rating.min_rating = Integer(xml_node['min_rating'])
    feature_rating.max_rating = Integer(xml_node['max_rating'])
    feature_rating.user_category = xml_node['user_category']
    feature_rating
  end

  def generate_xml(top_node)
    node_feature_rating = super(top_node)
    node_feature_rating['min_rating'] = min_rating.to_s
    node_feature_rating['max_rating'] = max_rating.to_s
    node_feature_rating['user_category'] = user_category
    node_feature_rating
  end

  def product_template_comment() "a number between #{min_rating} and #{max_rating}" end

  # define the distance between  2 products for this feature
  def distance_metric(product1, product2) (get_value(product1) - get_value(product2)).abs end

  def get_value_01(product)
    #Root.rule3(get_value(product).to_f, min_rating.to_f, max_rating.to_f)
    get_value(product).to_f
  end

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


  # this is included in a form
  def get_value_edit_html(product)
    "<div class=\"field\">
      <span>rating (min=#{min_rating}, max=#{max_rating})</span>
      <input type='text' name='feature_#{idurl}' value='#{get_value(product)}' />
    </div>"
  end

  def get_feature_html()
    suffix = "#{Root.icon_star}#{feature_html_suffix}"
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

  # ---------------------------------------------------------------------

  def is_specification?(product) false end

end

# define 2 sub features of same type (subtype of continoueus)
# first feature aggregated value < second feature aggregated value
class FeatureInterval < Feature

  key :class_name, String
  many :interval, :class_name => "Feature", :polymorphic => true

  def feature_min() interval.first end
  def feature_max() interval.last end

  def self.initialize_from_xml(xml_node)
    feature_interval = super(xml_node)
    feature_interval.class_name = xml_node['class_name']
    feature_interval.read_xml_list(xml_node, "Feature", :container_tag => 'ranges', :set_method_name => 'interval')
    feature_interval.interval.size
    raise "****** error #{xml_node.inspect}" unless feature_interval.interval.size == 2
    feature_interval
  end

  def generate_xml(top_node)
    node_feature_interval = super(top_node)
    node_feature_interval['class_name'] = class_name
    Root.write_xml_list(xml_node, interval, 'ranges')
    node_feature_interval
  end

  def get_value_01(product)
    # todo
    0.0
  end

  def product_template_comment() "[#{class_name}, #{class_name}]" end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array made of the value of min features float between 0 and 1
  def get_value(product)
    value_min = feature_min.get_value_html(product)
    value_max = feature_max.get_value_html(product)
    [value_min, value_max] if value_min or value_max
  end

  def get_value_html(product)
    if get_value(product)
      "#{feature_min.get_value_html(product)} #{feature_min.get_value_html(product)}"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    feature_min.get_value_edit_html(product) << feature_max.get_value_edit_html(product)
  end

  def get_feature_html() "<span title=\"interval of class#{class_name}\">#{label}</span>" end

  # this is included in a form
  def get_feature_edit_html()
    super()
  end

  SEPARATOR_INERVAL = '-@@-'
  def xml2value(content_string)
    content_string_min, content_string_max = content_string.split(SEPARATOR_INERVAL)
    value_min = content_string_min ? feature_min.xml2value(content_string_min) : nil
    value_max = content_string_max ? feature_max.xml2value(content_string_max) : nil
    [value_min, value_max]
  end

  def value2xml(value)
    xml_min = value.first ? feature_min.value2xml(value.first) : nil
    xml_max = value.last ? feature_max.value2xml(value.last) : nil
    "#{xml_min}#{SEPARATOR_INERVAL}#{xml_max}"
  end
  # ---------------------------------------------------------------------


end


# ----------------------------------------------------------------------------------------
# Continous (Abstract)
# ----------------------------------------------------------------------------------------

class FeatureContinous < Feature

  key :value_min, Object
  key :value_max, Object
  key :value_format, String

  # self.initialize_from_xml(xml_node) and generate_xml are defined in sub classes

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array made of the value of min features float between 0 and 1


  def get_value_html(product)
    if get_value(product)
      "#{format_value(get_value(product))}#{feature_html_suffix}"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    feature_continous_value =  get_value(product)
    feature_continous_value ||= ""
    "<div class=\"field\">
        <input type='text' name='feature_#{idurl}' value='#{feature_continous_value}' />
     </div>"
  end

  def get_feature_html() "<span title=\"feature #{self.class}\">#{label}</span>#{feature_html_suffix}" end

  # this is included in a form
  def get_feature_edit_html()
    super() << "<div class=\"field\">
                   format <input type='text' name='format' value='#{value_format}' />
                </div>"
  end


  # ---------------------------------------------------------------------


  # return the min max values
  def range(among_products)
    l = among_products.collect { |p| get_value(p)  }.sort!
    (l and min = l.min < max = l.max) ? [min, max] : [value_min, value_max]
  end

  def distance_metric(product1, product2)
    Float(get_value(product1) - get_value(product2)).abs
  end

end

class FeatureNumeric < FeatureContinous

  def self.initialize_from_xml(xml_node)
    feature_numeric = super(xml_node)
    feature_numeric.value_min = Float(xml_node['value_min'] || 0.0)
    feature_numeric.value_max = Float(xml_node['value_max'] || 1000.0)
    feature_numeric.value_format = xml_node.attributes['format'] || "%.2f"
    feature_numeric
  end

  # self.initialize_from_xml(xml_node) is defined in sub classes
  def generate_xml(top_node)
    node_feature_numeric = super(top_node)
    node_feature_numeric['value_min'] = value_min.to_s
    node_feature_numeric['value_max'] = value_max.to_s
    node_feature_numeric['format'] = value_format
    node_feature_numeric
  end

  def format_value(numeric_value)
    begin
      value_format % numeric_value
    rescue
      numeric_value.to_s
    end

  end

  def get_value_01(product)
    value = get_value(product)
    Root.rule3(value, value_min, value_max) if value
  end

  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) Float(content_string.strip) end
  def value2xml(value) value.to_s end

  def product_template_comment() "a number between #{value_min} and #{value_max}" end

end

class FeatureDate < FeatureContinous

  YEAR_IN_SECONDS = 60 * 60 * 24 * 365

  def self.initialize_from_xml(xml_node)
    feature_date = super(xml_node)
    feature_date.value_min = (date_min = xml_node['value_min']) ?  xml2date(date_min) : Time.now - 10 * YEAR_IN_SECONDS
    feature_date.value_max = (date_max = xml_node['value_max']) ?  xml2date(date_max) : Time.now + 10 * YEAR_IN_SECONDS
    feature_date.value_format = xml_node['format'] || Root.default_date_format
    feature_date
  end
  def self.xml2date(date) Time.parse(date) end

  # self.initialize_from_xml(xml_node) is defined in sub classes
  def generate_xml(top_node)
    node_feature_date = super(top_node)
    node_feature_date['value_min'] = FeatureDate.date2xml(value_min)
    node_feature_date['value_max'] = FeatureDate.date2xml(value_max)
    node_feature_date['format'] = value_format
    node_feature_date
  end
  def self.date2xml(x) x.strftime(Root.default_date_format) end

  # see http://ruby-doc.org/core-1.9/classes/Time.html#M000314
  def format_value(date) date.strftime(value_format) end

  def get_value_01(product) Root.rule3(get_value(product), value_min, value_max) end


  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) FeatureDate.xml2date(content_string.strip) end
  def value2xml(value) FeatureDate.date2xml(value) end

  def product_template_comment() "a date between #{value2xml(value_min)} and #{value2xml(value_max)}" end

end

# ----------------------------------------------------------------------------------------
# Condition
# ----------------------------------------------------------------------------------------

# value is a boolean
class FeatureCondition < Feature

  def self.initialize_from_xml(xml_node)
    feature_condition = super(xml_node)
  end

  def generate_xml(top_node)
    node_feature_condition = super(top_node)
  end

  def get_value_01(product) get_value(product) ? 1.0 : 0.0 end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array of tag.idurl

  def get_value_html(product)
    unless (value = get_value(product)).nil?
      "<img src=\"/images/icons/opinion_#{value ? 'ok' : 'ko' }.jpg\" />"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    "<input type='checkbox' name='feature_#{idurl}' title='idurl=#{idurl}' value='#{idurl}' #{ get_value(product) ? 'checked' : nil} />#{label}"
  end

  def product_template_comment() "true or false" end

  # ---------------------------------------------------------------------

  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string)
    content_string = content_string.strip
    content_string != "" and content_string.downcase != "false"
  end
  def value2xml(value) value.to_s end

  def is_specification?(product) super(product) and get_value(product) end

end

# ----------------------------------------------------------------------------------------
# Computed (value comes for combination of other feature)
# ----------------------------------------------------------------------------------------

# value is the result of the formula !
class FeatureComputed < Feature

  key :formula, String

  def self.initialize_from_xml(xml_node)
    feature_computed = super(xml_node)
    feature_computed.formula_string = xml_node['formula']
    raise "error, no formula" unless feature_computed.formula_string
    feature_computed
  end

  def generate_xml(top_node)
    node_feature_computed = super(top_node)
    node_feature_computed['formula'] = formula_string
    node_feature_computed
  end

  def get_value_01(product) 0.0 end

  # ---------------------------------------------------------------------
  def get_value_html(product) get_value(product).to_s end

  # this is included in a form
  def get_value_edit_html(product) nil end

  # computation
  def get_value(product)
    FormulaEvaluator.new(knowledge, product).eval(formula)
  end

  # ---------------------------------------------------------------------
  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) raise "oups" end
  def value2xml(value) raise "oups" end

  # formula evaluator
  class Evaluator

    def initialize(knowledge, product)
      @knowledge = knowledge
      @product = product
    end

    def eval(formula) self.eval_instance_eval(formula) end

    # language itself
    def featureIs(idurl_feature)
      @knowledge.get_feature_by_idurl(feature_idurl).get_value(product)
    end

  end

end

# ----------------------------------------------------------------------------------------
# Text (use for label, description, etc...)
# ----------------------------------------------------------------------------------------

# value is line of text
class FeatureText < Feature
  def product_template_comment() "a string" end
end

# value is a URL
class FeatureTextarea < Feature
  def get_value_html(product)
    if url = get_value(product)
      "<a href=\"#{knowledge.clean_url(url, product)}\">link</a>"
    end
  end

  def product_template_comment() "an url, like files/toto.html" end

end

class FeatureImage < Feature

  def get_value_html(product)
    if url = get_value(product)
      "<img src=\"#{knowledge.clean_url(url, product)}\" width=\"100\" height=\"100\" />"
    end
  end

  def product_template_comment() "an url, like images/mabelle_image.png" end


end

class FeatureUrl < Feature
  def get_value_html(product)
    if url = get_value(product)
      "<a href=\"#{knowledge.clean_url(url, product)}\">link</a>"
    end
  end

  def product_template_comment() "an url, like <![CDATA[ http//amazon.com/iphone.html ]]>" end

end
# define a feature with no value
class FeatureHeader < Feature

  def color_from_status(product) "lightblue" end

  def get_value_edit_html(product) "" end

end

