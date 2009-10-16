require 'pkz_xml.rb'

module Pikizi


# The root of all objects of the model (Feature, Question, Choice, ...)
# Aggregated value (background)

class Model < Root
  # abstract class 
  
  attr_accessor :knowledge, :hash_key_background
    
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node)
    self.knowledge = knowledge
    self.key ||= "model##{knowledge.new_index}"
    self.hash_key_background = Root.get_hash_from_xml(xml_node, 'background', 'key') { |node_background| Background.create_from_xml(node_background) }
  end

  def generate_xml(top_node, class_name)
    node_model = super(top_node, class_name)
    hash_key_background.each { |key, background| background.generate_xml(node_model) }  if hash_key_background
    node_model
  end

  def knowledge_key() knowledge.key end
  
  def self.create_from_xml(xml_node, knowledge)
    (x = self.create_new_instance_from_xml(xml_node)).initialize_from_xml(xml_node, knowledge); x
  end

  # return a hash background_key, background object
  # for the feature, or the feature/product
  def get_backgrounds(product=nil)
    product ? product.get_backgrounds(knowledge_key, key) : hash_key_background
  end

end

# =======================================================================================
# Describe a hierarchy of features
# =======================================================================================

class Feature < Model
  # abstract class 
  
  attr_accessor :feature_parent, :sub_features, :min_rating, :max_rating, :rating_by, :weight_in_product_distance

  def initialize_from_xml(xml_node, feature_parent)
    super(xml_node, feature_parent ? feature_parent.knowledge : self)
    self.feature_parent = feature_parent
    self.min_rating = (xml_node['min_rating'] || nil)
    self.max_rating = (xml_node['max_rating'] || nil)
    self.rating_by = (xml_node['rating_by'] || nil)
    self.weight_in_product_distance = Float((xml_node['distance'] || 0.0))
    self.sub_features = Root.get_collection_from_xml(xml_node, "sub_features/feature") { |node| Feature.create_from_xml(node, self) }
    knowledge.hash_key_feature[key] = self
  end

  # a feature is ratable when...
  def is_ratable?() rating_by and min_rating and max_rating end

  def is_root?() feature_parent.nil? end

  def label_full() is_root? ? label : "#{feature_parent.label_full}/#{label}" end

  
  def self.create_new_instance_from_xml(xml_node) 
    Pikizi.const_get("Feature#{xml_node['type'].capitalize}").new
  end
  
  def self.create_from_xml(xml_node, feature_parent) 
    (x = self.create_new_instance_from_xml(xml_node)).initialize_from_xml(xml_node, feature_parent); x
  end
  
  def generate_xml(top_node, classname=nil)
    raise "error" if classname    
    type = self.class.to_s.downcase; type.slice!("pikizi::feature")
    node_feature = super(top_node, "feature") 
    node_feature['type'] = type
    node_feature['min_rating'] = min_rating.to_s if min_rating
    node_feature['max_rating'] = max_rating.to_s if max_rating
    node_feature['rating_by'] = rating_by if rating_by
    node_feature['distance'] = weight_in_product_distance.to_s if weight_in_product_distance != 0.0

    if sub_features and sub_features.size > 0      
      node_feature << (node_sub_features = XML::Node.new('sub_features'))
      sub_features.each { |sf| sf.generate_xml(node_sub_features) }
    end
    node_feature
  end

  def generate_xml_4_value(node_featuredata, featuredatas)
    if featuredata = featuredatas[key] and featuredata.values.size > 0  and featuredata.values.first  and featuredata.values.first != ""
      node_featuredata << (node_value = XML::Node.new('value'))
      node_value << featuredata.values.first 
    end
    node_featuredata
  end


  # translate to html
  def to_html(product, extra, deep_down)

    # backgrounds for knowledege feature
    html_node = ""

    # background_icon
    url = "/medias/#{knowledge_key}/"
    url << (product ? "product/#{product.key}" : "model")
    url << "/#{key}" if feature_parent
    backgrounds_size = get_backgrounds(product) ? get_backgrounds(product).size : 0
    backgrounds_size = (backgrounds_size > 0 ? backgrounds_size : nil )
    bgk_icon = "<a href=\"#{url}\" class='pkz_background' title='#{backgrounds_size || 0} backgrounds for #{label}#{(' on ' << product.label) if product}'>&nbsp;#{backgrounds_size || '&nbsp;'}&nbsp;</a>"


    if feature_parent
      html_node << "<span class='pkz_feature_label' title='key=#{key}'>#{label}</span>"
      html_node << "#{bgk_icon}<span class='pkz_feature_extra'>#{extra}</span>"
      html_node  << "#{get_html_editor(product)}"
    else
      # this the the root, i.e. the knowledge object
      html_node << "#{product ? product.label : 'product'}#{bgk_icon}"
    end 

    s_options = (deep_down and sub_features) ? sub_features.collect { |f| "<li>#{f.to_html(product, nil, deep_down)}</li>" } : []
    s_options = (s_options.size > 0) ? "<ul>#{s_options}</ul>" : nil
    "#{html_node}#{s_options}"
  end

  def get_html_editor(product)
    if product
      values = get_values(product).collect { |v| value2string(v) }
      "<input type='text' values='#{values.join(', ')}' />"
    else
      "N/A"
    end
  end

  def label_hierarchical(first=true) feature_parent ? "#{feature_parent.label_hierarchical(nil)}#{label}#{'/' unless first}" : "" end

  # use to explore thefeature hierarchicly
  # a block should return somethinf for a feature
  # return a hierarchical list
  def each_feature_collect(except_first, &block)
    l = []
    l << [block.call(self)] unless except_first
    l << semantic_sub_features.collect { |sub_feature| sub_feature.each_feature_collect(false, &block) } if semantic_sub_features.size > 0
    l
  end

  def semantic_sub_features() sub_features end

  # ------------------------------------------------------------------------------------------
  # manage the value for a given feature / product
  # ------------------------------------------------------------------------------------------
  # nil is never in domain
  # if u want to set the value to nil, use empty_value instead
  def is_valid_value?(value_as_string)
    begin
      string2value(value_as_string)
      true
    rescue
      false
    end
  end

  # convert a string value to a value, if impossible raises an error
  def string2value(x) x end
  def value2string(x) x.to_s end

  # define the distance between  2 products for this feature
  def distance(product1, product2)
    begin
      distance_metric(product1, product2)
    rescue
      "ERR"
    end
  end
  def distance_metric(product1, product2) "Undef #{get_value(product1).inspect}" end


  # return the  FeatureValue(s) for a product
  # return nil, if no value
  def get_values(product)
    values = product.get_values(knowledge_key, key)
    # puts "***** #{product.key} values for feature #{label} #{self.class} = #{values.inspect}"
    values.collect {|v|  (v.nil? or v == "") ? nil : string2value(v) } if values
  end

  def get_value(product) get_values(product).first end

  # ------------------------------------------------------------------------------------------
  # manage the background for a given feature / product
  # ------------------------------------------------------------------------------------------

  def set_background(product, user, auth_background)
    ar_background = ActiveRecord::Base::Background.get_or_create_from_auth(self, product, user, auth_background)
    

    if product
      product.set_background(auth_background, user, knowledge_key, key)
    else
      # TODO set background for feature (no product)
    end
  end



  # ------------------------------------------------------------------------------------------
  # misc
  # ------------------------------------------------------------------------------------------

  # iterate over all the features of the model, depth first
  def each_feature(&action)
    sub_features.each { |f| f.each_feature(&action) } if sub_features
    action.call(self)
  end

  # count the number of features
  def nb_features() nb = 0; each_feature { |f| nb += 1 }; nb end
               
end


# this is the root of the model
# and the first object to instanciate
# root of:
# a hierarchy of sub_features
# a list of questions
class Knowledge < Feature

  attr_accessor :questions, :product_keys, :current_index, :hash_key_feature, :quizzes


  def initialize_from_xml(xml_node, feature_parent=nil)
    self.current_index = Integer(xml_node.attributes['current_index'] || 0)
    self.hash_key_feature = {}
    super(xml_node.find_first('feature'), nil)
    self.product_keys = Root.get_collection_from_xml(xml_node, 'feature/product_keys/product') { |node_product| node_product.attributes["key"] }
    self.questions = Root.get_collection_from_xml(xml_node, 'feature/questions/question') { |node_question| Question.create_from_xml(node_question, self) }
    if node_quizzes = xml_node.find_first('feature') and xml_node.find_first('quiz')
      self.quizzes = Root.get_collection_from_xml(xml_node, 'feature/quizzes/quiz') { |node_quiz| Quiz.create_from_xml(node_quiz, self) }
    else
      self.quizzes = [Quiz.create_with_parameters(key, product_keys)]
    end

  end

  def self.get_from_cache(knowledge_key, reload=nil)
    Rails.cache.fetch("K#{knowledge_key}", :force => reload) { Knowledge.create_from_xml(knowledge_key) }
  end


  # load an xml file... and retutn a Knowledge object
  def self.create_from_xml(knowledge_key)
    unless key_exist?(knowledge_key)
      pkz_knowledge = Knowledge.new
      pkz_knowledge.key = knowledge_key
      pkz_knowledge.label = "Label for #{knowledge_key}"
      pkz_knowledge.save # save in a file
    end
    PK_LOGGER.info "loading XML knowledge #{knowledge_key} from filesystem"    
    xml_node = XML::Document.file(filename_data(knowledge_key)).root
    (k = Knowledge.new).initialize_from_xml(xml_node, nil); k
  end

  def generate_xml(doc)
    doc.root = node_knowledge = XML::Node.new('knowledge')
    node_knowledge = super(node_knowledge)
    node_knowledge['current_index'] = current_index.to_s
    node_knowledge << (node_questions = XML::Node.new('questions'))
    questions.each { |question| question.generate_xml(node_questions) }
    node_knowledge << (node_product_keys = XML::Node.new('product_keys'))
    product_keys.each { |product_key|  node_product_keys << (node_product_key = XML::Node.new('product')); node_product_key["key"] = product_key }
    node_knowledge << (node_quizzes = XML::Node.new('quizzes'))
    quizzes.each { |quiz| quiz.generate_xml(node_quizzes) }
    node_knowledge
  end

  # translate to html
  def to_html(product=nil)
    raise "product class wrong=#{product.inspect}" if product and !product.is_a?(Pikizi::Product)
    hidden_tail = ""
    hierarchy = super(product, "", true)
    hierarchy << hidden_tail
  end
  
  # the  index ... (for anything with superclass model)
  # TODO not compliant with multiple ruby instances! 
  def new_index() @current_index += 1 end
  
  # a value for the feature model is the product key
  def is_valid_value?(value) true end
  
  # return the number of products handled by this model
  def nb_products() product_keys.size end

  # returns all products...
  def products() product_keys.collect {|pkey| Product.get_from_cache(pkey) } end


  # return the number of questions handled by this model
  def nb_questions() questions.size end

  # sort the questions by criterions
  def questions_sorted(products, user)
    questions_with_discrimination = questions.collect { |q| [q, q.discrimination(user)] }
    question_with_discrimination_sorted = questions_with_discrimination.sort! { |q1, q2| q2.last <=> q1.last }
    question_with_discrimination_sorted.collect(&:first)
  end


  # return the number of questions handled by this model
  def nb_quizzes() quizzes.size end

  # return the number of recommendations handled by this model
  def nb_recommendation() questions.inject(0) { |s, q| s += q.nb_recommendation } end

  # cancel the recommendations generated by a previous answer
  def cancel_recommendations(question, last_answer, quiz_instance, products)
    tips_triggered = tips.find_all { |tip| tips_keys_triggered.include?(tip.key) }
    choices_ok = question.choices.find_all { |c| last_answer.choice_keys_ok.include?(c.key) }
    propagate_recommendations(question, choices_ok, quiz_instance.hash_pkey_affinity, products, true)
  end

  # propagate the recommendations associated with the choices_ok
  # update hash_pkey_affinity ( a hash table between a product-key and and a user affinity)
  def propagate_recommendations(question, choices_ok, hash_pkey_affinity, products, reverse_mode)
    choices_ok.each do |choice_ok|
      choice_ok.generate_hash_pkey_weight(products).each do |pkey, weight|
        if question.is_filter
          raise "filtering not implemented yet"
        else
          hash_pkey_affinity[pkey] += weight * (reverse_mode ? -1.0 : 1.0)
        end
      end
    end
  end

  # return a new affinity list
  def trigger_tips(quiz_instance, question, products, choices_ok, simulation)

    choice_keys_ok = choices_ok.collect(&:key)
    answer = quiz_instance.record_answer(self.key, question.key, choice_keys_ok)

    hash_pkey_affinity = quiz_instance.hash_productkey_affinity
    hash_pkey_affinity = hash_pkey_affinity.inject({}) { |h, (pkey, a)| h[pkey] = a.clone } if simulation


    propagate_recommendations(question, choices_ok, hash_pkey_affinity, products, false)

    quiz_instance.cancel_answer(answer) if simulation


    hash_pkey_affinity

  end

  def get_question_from_key(q_key) questions.detect { |q| q.key == q_key } end

  def get_feature_by_key(f_key) hash_key_feature[f_key] end

  # cache management for:
  # number of time a question was presented
  # number of time a question was answered
  # number of time a given choice was selected
  def self.counter_question_presentation(knowledge_key, question_key, options={}) cache_action("#{knowledge_key}@#{question_key}@presentation", options) end
  def self.counter_question_oo(knowledge_key, question_key, options={}) cache_action("#{knowledge_key}@#{question_key}@oo", options) end
  def self.counter_choice_ok(knowledge_key, question_key, choice_key, options={}) cache_action("#{knowledge_key}@#{question_key}@#{choice_key}@ok", options) end
  def self.cache_action(key, options)
    if options.size == 0 # no options
      Rails.cache.fetch(key)
    elsif initial_value = options[:initialize]
      puts "writing initial value=#{initial_value}"
      Rails.cache.write(key, initial_value)
    elsif options[:increment] > 0
      Rails.cache.increment(key)
    elsif options[:increment] < 0
      Rails.cache.decrement(key)
    else
      raise "error unknown options=#{options.inspect}"
    end
  end

end

# define a group of sub features of type FeatureBinary
class FeatureTag < Feature

  attr_accessor :is_exclusive, :feature_binaries
  
  def initialize_from_xml(xml_node, feature_parent) 
    super(xml_node, feature_parent)
    self.is_exclusive = (xml_node['is_exclusive'] == "true" ? true : false)
    self.feature_binaries = Root.get_collection_from_xml(xml_node, "tags/feature") do |node_feature_binary|
      fb = FeatureBinary.create_from_xml(node_feature_binary, self)
      fb.is_exclusive = is_exclusive
      fb
    end
  end
  
  def generate_xml(top_node, classname=nil)
    node_feature_tag = super(top_node, classname) 
    node_feature_tag['is_exclusive'] = is_exclusive.to_s
    node_feature_tag << (node_tags = XML::Node.new('tags'))
    feature_binaries.each { |feature_binary|  feature_binary.generate_xml(node_tags) }
    node_feature_tag
  end

  def generate_xml_4_value(node_featuredata, featuredatas)
    values = featuredatas[key].values
    feature_binaries.each do |sf|
      node_featuredata << XML::Node.new_comment("#{sf.key} : #{sf.label}")
      if values.include?(sf.key)
        node_featuredata << (node_value = XML::Node.new('value'))
        node_value << sf.key
      end

    end
    node_featuredata
  end

  def to_html(product, extra, deep_down)
    extra = feature_binaries.collect { |sf| sf.label }.join(", ")  unless product
    super(product, extra, false)
  end

  def semantic_sub_features() [] end
  
  def get_html_editor(product)
    if product
      values = get_values(product)
      feature_binaries.collect do |sf|
        type_button = is_exclusive ? 'radio' : 'checkbox'
        "<input type='#{type_button}' name='feature_#{sf.key}' title='key=#{sf.key}' value='#{sf.key}' #{ values.include?(sf.key) ? 'checked' : nil} />#{sf.label}"
      end.join(", ")
    else
      ""
    end
  end

  
  def is_valid_value?(feature_tag_keys)
    all_feature_tag_keys = feature_binaries.collect(&:key) 
    feature_tag_keys.all? { |feature_tag_key| all_feature_tag_keys.include?(feature_tag_key) }
  end
  
  # return 2 arrays of feature_tag_keys used as minima, maxima in among products
  # minima = intersection of all feature tag keys
  # maxima = union of all feature tag keys
  def range(among_products)
    all_feature_tag_keys = sub_features.collect(&:key)     
    min, max = among_products.inject([Set.new(all_feature_tag_keys), Set.new]) { |(intersection, union), product| 
      product_tag_keys = product.get_value(knowledge_key, key, product)
      product_tag_keys ? [i.intersection(product_tag_keys), u.merge(product_tag_keys)] : [intersection, union]
    }
    max.size > min.size ? [min, max] : [[], all_feature_tag_keys]
  end
  
  
end

# define a rating value
# aggregations objects are attached for each fetaureRating/Product 
class FeatureRating < Feature
  attr_accessor :min_rating, :max_rating, :user_categories

  def initialize_from_xml(xml_node, feature_parent)
    super(xml_node, feature_parent)
    self.min_rating = Integer(xml_node['min_rating'])
    self.max_rating = Integer(xml_node['max_rating'])
    self.user_categories = xml_node['user_categories'].split(",")
  end

  def generate_xml(top_node, classname=nil)
    node_feature_rating = super(top_node, classname)
    node_feature_rating['min_rating'] = min_rating.to_s
    node_feature_rating['max_rating'] = max_rating.to_s
    node_feature_rating['user_categories'] = user_categories.join(",")
    node_feature_rating
  end

  
  # define the distance between  2 products for this feature
  def distance_metric(product1, product2) (get_value(product1) - get_value(product2)).abs end

  def get_value(product)
    begin
      Float(super(product))
    rescue
      nil  
    end
  end
  
  #   "<span class='pkz_rating' title='ratable by: #{user_categories.join(', ')}'>&nbsp;#{user_categories.size}&nbsp;</span>"

  def get_html_editor(product)
    if product
      values = get_values(product)
      value = values.first
      value = Float(value) if value
      authors = values[1, values.length - 1]

      if value
        s = "<span title='authors:#{authors.join(', ')}'>"
        for i in 1..value.round
          s << "<span class='pkz_rating'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>"  
        end
        s << "</span>"
      else
        "<span class='pkz_rating' title='no rating!, ratable by: #{user_categories.join(', ')}' style='margin-left:3px;'>&nbsp;?&nbsp;</span>"
      end
    else
      "<span class='pkz_rating' title='ratable by: #{user_categories.join(', ')}' style='margin-left:3px;'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>"      
    end
  end

  def to_html(product, extra, deep_down)
    extra = "min=#{min_rating} max=#{max_rating}"  unless product
    super(product, extra, false)
  end

  def generate_xml_4_value(node_featuredata, featuredatas)
    featuredatas[key].values.each do |value|
      node_featuredata << (node_value = XML::Node.new('value'))
      node_value << value
    end
    node_featuredata
  end

end

# define 2 sub features of same type (subtype of continoueus)
# first feature aggregated value < second feature aggregated value
class FeatureInterval < Feature

  attr_accessor :class_name, :feature_min, :feature_max
  
  def initialize_from_xml(xml_node, feature_parent)    
    super(xml_node, feature_parent)
    self.class_name = xml_node['class_name']
    self.feature_min, self.feature_max  = Root.get_collection_from_xml(xml_node, "ranges/feature") do |node_feature|
      Feature.create_from_xml(node_feature, self) 
    end
  end
  
  def generate_xml(top_node, classname=nil)
    node_feature_interval = super(top_node, classname) 
    node_feature_interval['class_name'] = class_name
    node_feature_interval << (node_ranges = XML::Node.new('ranges'))
    [feature_min, feature_max].each { |feature_range| feature_range.generate_xml(node_ranges) }
    node_feature_interval
  end

  
  # value is an array of 2 values
  def is_valid_value?(value)
    raise "error" unless value.is_a?(Array) and value.size == 2
    value_min, value_max = value.min, value.max
    feature_min.is_valid_value?(value_min) and feature_max.is_valid_value?(value_max)
  end

  def generate_xml_4_value(node_featuredata, featuredatas)
    [feature_min, feature_max].each do |sf|
      node_featuredata << XML::Node.new_comment("#{sf.key} : #{sf.label}")
      feature_data = featuredatas[sf.key]
      featuredata_value = feature_data ? feature_data.value : nil
      featuredata_value_value = featuredata_value ? featuredata_value.value : nil
      node_featuredata << (node_value = XML::Node.new('value'))
      node_value << featuredata_value_value

    end
    node_featuredata
  end

  def get_html_editor(product)
    if product
      min, max = get_values(product)
      "<input type='text' value='#{min} -- #{max}' />"
    else
      ""
    end
  end


end


# ----------------------------------------------------------------------------------------
# Continous
# ----------------------------------------------------------------------------------------

class FeatureContinous < Feature
  
  attr_accessor :value_min, :value_max, :format
  
  def generate_xml(top_node, classname=nil)
    node_feature_continous = super(top_node, classname) 
    node_feature_continous['format'] = format
    node_feature_continous['value_min'] = value2string(value_min)
    node_feature_continous['value_max'] = value2string(value_max)
    node_feature_continous
  end
  
  # translate to html
  def to_html(product, extra, deep_down) super(product, "[#{format_value(value_min)} ... #{format_value(value_max)}]", deep_down) end

  def get_html_editor(product)
    if product
      v = get_value(product)
      "<input type='text'    value='#{ v ? format_value(v) : nil}' />"
    else
      ""
    end
  end

  # abstract class 
  
  def is_valid_value?(value_as_string)
    begin
      value = string2value(value_as_string)
      value >= value_min and value <= value_max
    rescue
      false
    end
  end
  
  # return the min max values
  def range(among_products)
    l = among_products.collect { |p| get_value(p)  }.sort!
    (l and min = l.min < max = l.max) ? [min, max] : [value_min, value_max]
  end

  
end

class FeatureNumeric < FeatureContinous

  def initialize_from_xml(xml_node, feature_parent)
    super(xml_node, feature_parent)
    self.value_min = string2value(xml_node['value_min'] || 0.0)
    self.value_max = string2value(xml_node['value_max'] || 1000.0)
    self.format = xml_node.attributes['format'] || "%.2f"
  end
  
  def format_value(x) format % x end
  def string2value(x) Float(x) end

  def distance_metric(product1, product2)
    Float(get_value(product1) - get_value(product2)).abs
  end
  
end

class FeatureDate < FeatureContinous

  YEAR_IN_SECONDS = 60 * 60 * 24 * 365

  def initialize_from_xml(xml_node, feature_parent)
    super(xml_node, feature_parent)
    self.value_min = (date_min = xml_node['value_min']) ?  string2value(date_min) : Time.now - 10 * YEAR_IN_SECONDS
    self.value_max = (date_max = xml_node['value_max']) ?  string2value(date_max) : Time.now + 10 * YEAR_IN_SECONDS
    self.format = xml_node['format'] || Root.default_date_format
  end
  
  def format_value(x) x.strftime(format) end
  def string2value(x) Time.parse(x) end
  def value2string(x) x.strftime(Root.default_date_format) end

end

# ----------------------------------------------------------------------------------------
# Binary
# ----------------------------------------------------------------------------------------

class FeatureBinary < Feature

  attr_accessor :is_exclusive
    
  def initialize_from_xml(xml_node, feature_parent) 
    super(xml_node, feature_parent)
    self.is_exclusive = (xml_node['is_exclusive'] == 'true' ? true : false)
  end
  
  def generate_xml(top_node, classname=nil)
    node_feature_binary = super(top_node, classname) 
    node_feature_binary['is_exclusive'] = is_exclusive.to_s
    node_feature_binary
  end
  
  def string2value(x)
    case x
      when "true" then true
      when "false" then false
      else raise "Error a binary should be true or false : #{x}"
    end
  end

  def get_html_editor(product)
    if product
      raise "error" unless   feature_parent
      type_button = is_exclusive ? 'radio' : 'checkbox'
      "<input type='#{type_button}'   name='feature_#{key}' value='#{key}' #{(get_values(product) == true) ? 'checked' : nil} />#{label}" 
    else
      "N/A"
    end
  end

end


# ----------------------------------------------------------------------------------------
# Text (use for label, description, etc...)
# ----------------------------------------------------------------------------------------

class FeatureText < Feature
    
end

class FeatureTextarea < Feature
    
end

# define a feature with no value
class FeatureHeader < Feature

  def get_html_editor(product) "" end
end



# =======================================================================================
# Questions
# =======================================================================================

# a question has binary choices... (can be exclusive choices)
# a precondition to be askable (per default true)
# Answers to Question define user cluster
# Question/Answer can be set-up, from already existing customer profile data
class Question < Model

  attr_accessor :is_choice_exclusive, :choices, :precondition_expression
  attr_accessor :nb_presentation_static, :nb_oo_static, :is_filter

  def nb_presentation() @nb_presentation ||= (Knowledge.counter_question_presentation(knowledge_key, key) || nb_presentation_static) end
  def nb_oo() @nb_oo ||= (Knowledge.counter_question_oo(knowledge_key, key) || nb_oo_static) end

  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.is_choice_exclusive = (xml_node['is_exclusive'] == 'true' ? true : false)
    self.nb_presentation_static = Float(xml_node['nb_presentation'] || 0.0)
    self.nb_oo_static = Float(xml_node['nb_oo'] || 0.0)
    self.is_filter = xml_node['is_filter']
    self.choices = Root.get_collection_from_xml(xml_node, "choice") { |node_choice| Choice.create_from_xml(node_choice, knowledge, self) }
    node_expression = xml_node.find_first('if/expression')
    self.precondition_expression = (Expression.create_from_xml(node_expression) if node_expression)
  end
  
  
  def generate_xml(top_node, classname=nil)
    node_question = super(top_node, classname) 
    node_question['is_exclusive'] = is_choice_exclusive.to_s
    node_question['nb_presentation'] = nb_presentation.to_s
    node_question['nb_oo'] = nb_oo.to_s
    node_question['is_filter'] = "true" if is_filter
    node_question << (node_if = XML::Node.new('if'))
    precondition_expression.generate_xml(node_if) if precondition_expression
    choices.each { |choice| choice.generate_xml(node_question) }
    node_question
  end
  
  def nb_choices() @nb_choices ||= choices.size end
  def default_choice_proba_ok() is_choice_exclusive ? 1.0 / nb_choices.to_f : 0.5 end

  # return the number of recommendations handled by this question
  def nb_recommendation() choices.inject(0) { |s, c| s += c.nb_recommendation } end


  # based on precondition expression 
  def is_askable?(quiz_instance) precondition_expression ? precondition_expression.evaluate(quiz_instance) : true end

  # step #2.1 record_answer (called by user.record_answer)
  def record_answer(user, choices_ok, reverse_mode)
   increment = reverse_mode ? -1.0 : +1.0

   Knowledge.counter_question_presentation(knowledge_key, key, {:increment => increment})

    if choices_ok.size == 0
      # this is a no opinion
      Knowledge.counter_question_oo(knowledge_key, key, {:increment => increment})
    else
      choices_ok.each { |choice| choice.record_answer(user, reverse_mode) }
    end
  end

  def enumerator(debug = nil)
    e = is_choice_exclusive ? enumerator_exclusive(debug) : enumerator_inclusive(debug)
    PK_LOGGER.debug "---------------------------"  if debug
    result = e.inject({}) do |h, (pkey, distributions)|
      h[pkey] = Distribution.merge_by_weight(distributions)
      PK_LOGGER.info "#{pkey} =>  #{h[pkey].join(', ')}"  if debug
      h
    end
    PK_LOGGER.info "---------------------------"  if debug
    result
  end



  def enumerator_inclusive(debug, n=nil, result=[], current_proba=1.0, cumulator={})
    n ||= choices.size
    if n == 0
      cumulator = Distribution.each_propa_choices(current_proba, result, cumulator, debug)
    else
      n -= 1
      choice = choices[n]; proba_ok = choice.proba_ok
      enumerator_inclusive(debug, n, result, current_proba * (1.0 - proba_ok), cumulator)
      enumerator_inclusive(debug, n, result.clone << choice, current_proba * proba_ok, cumulator)
      cumulator
    end
  end

  def enumerator_exclusive(debug)
    null_proba = 1.0 - choices.inject(0.0) {|s,c| s += c.proba_ok}
    cumulator = Distribution.each_propa_choices(null_proba, [], {}, debug)
    for i in 0..choices.size-1
      choice = choices[i]
      Distribution.each_propa_choices(choice.proba_ok, [choice], cumulator, debug)
    end
    cumulator
  end



  # define the proba of no opinion 0.0 .. 1.0
  def proba_oo(user=nil) @nb_presentation == 0.0 ? 0.0 : (@nb_oo /  @nb_presentation) end     
  def proba_valid(user=nil) 1.0 - proba_oo(user) end
  def confidence() choices.collect(&:confidence).min end

  # get choice objects from their key
  def get_choice_ok_from_keys(choices_keys_selected_ok)
    choices.find_all { |choice| choice if choices_keys_selected_ok.include?(choice.key) }
  end

  def get_choice_from_key(choice_key) choices.detect {|c| c.key == choice_key } end

end


# ----------------------------------------------------------------------------------------
# Choices for a Question
# ----------------------------------------------------------------------------------------

# model a binary variable. true, false
class Choice < Model

  attr_accessor :recommendations, :question
  attr_accessor :nb_ok_static

  def nb_ok() @nb_ok ||= (Knowledge.counter_choice_ok(knowledge_key, question.key, key) || nb_ok_static) end
  def nb_ko() @nb_ko ||= (question.nb_presentation - nb_ok) end

  def proba_ok() (sum = nb_ok + nb_ko) == 0 ? question.default_choice_proba_ok : nb_ok / sum end
  def proba_ko() 1.0 - proba_ok end

  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.recommendations = Root.get_collection_from_xml(xml_node, 'recommendation') { |node_recommendation| Recommendation.create_from_xml(node_recommendation, knowledge) }
    self.nb_ok_static = Float(xml_node['nb_ok'] || 0.0)

  end

  def self.create_from_xml(node_xml, class_name, question)
    choice = super(node_xml, class_name)
    choice.question = question
    choice
  end

  def generate_xml(top_node, classname=nil)
    node_choice = super(top_node, classname) 
    node_choice['nb_ok'] = nb_ok.to_s
    recommendations.each { |recommendation| recommendation.generate_xml(node_choice) }
    node_choice
  end


  NB_ANSWERS_4_MAX_CONFIDENCE = 5.0
  # confidence on proba
  def confidence() [NB_ANSWERS_4_MAX_CONFIDENCE, nb_ok + nb_ko].min / NB_ANSWERS_4_MAX_CONFIDENCE end


  # record a choice by a user
  def record_answer(user, reverse_mode)
    Knowledge.counter_choice_ok(knowledge_key, question.key, key, {:increment => (reverse_mode ? -1.0 : +1.0)})
  end


  # return a hash product_key -> weight
  # options
  # - :add_null, add a null weight for all products per default
  def generate_hash_pkey_weight(products=nil, options={})
    if (is_cached = !(products or options[:add_null])) and @hash_pkey_weight
      @hash_pkey_weight
    else
      products ||= knowledge.products
      hash_pkey_weight = recommendations.inject({}) do |h, recommendation|
        recommendation.generate_hash_pkey_weight(products).each do |pkey, weight|
          h[pkey] = (h[pkey] || 0.0) + weight
        end
        h
      end
      products.each { |product| hash_pkey_weight[product.key] ||= 0.0 } if options[:add_null]
      @hash_pkey_weight = hash_pkey_weight if is_cached
      hash_pkey_weight
    end
  end

  
  def generate_javascript_weights(products)
    hash_pkey_weight = generate_hash_pkey_weight(products, :add_null => true).collect do |pkey, weight|
      "tr_arrow('#{pkey}','" << (weight != 0.0 ? weight.to_s : "&nbsp;") << "');"
    end.join(' ')
  end

  # return the number of recommendations handled by this question
  def nb_recommendation() recommendations.size end

  
end

# ----------------------------------------------------------------------------------------
# Expression == the IF part of a Recommendation
# or the Expression to check if a question is askable
# an expression on how the user answered to previous questions
# ----------------------------------------------------------------------------------------

class Expression  < Root
  # abstract class
  
  
  def self.create_new_instance_from_xml(xml_node) Pikizi.const_get("Expression#{xml_node['type'].capitalize}").new end
    
  def generate_xml(top_node, classname=nil)
    raise "error" if classname
    node_expression = super(top_node, "expression")
    type = self.class.to_s.downcase; 
    type.slice!("pikizi::expression")
    node_expression['type'] = type
    node_expression
  end
  
  def to_s() "??ERROR" end
  
end

# a collection of Expression
class ExpressionComposite < Expression
  attr_accessor :expressions
  
  def initialize_from_xml(xml_node) 
    super(xml_node)
    # TODO
    self.expressions = Root.get_collection_from_xml(xml_node, "???") { |sub_node| Expression.create_from_xml(sub_node)  }
    raise "error expressions is nil" unless expressions
    expressions
  end
  
  def generate_xml(top_node, classname=nil)
    node_expression = super(top_node, classname)
    expressions.each { |exp| exp.generate_xml(node_expression) }
    node_expression
  end

  def to_s() expressions.collect(&:to_s).join(', ') end

  def get_questionkey_choicekey_involved()
    expressions.inject([]) { |l, expression| l.concat(expression.get_questionkey_choicekey_involved); l }
  end

end

# semantic and
class ExpressionAnd < ExpressionComposite
  
  def evaluate(quiz_instance) expressions.all? { |e| e.evaluate(quiz_instance) } end

  def to_s() "and(#{super})" end

end

# semantic or
class ExpressionOr < ExpressionComposite

  def evaluate(quiz_instance) expressions.any? { |e| e.evaluate(quiz_instance) } end

  def to_s() "or(#{super})" end
  
end

# the user has answered a specific answer to a Choice object
# evaluate expects a quiz_instance object
class ExpressionAnswer < Expression
  attr_accessor :question_key, :choice_key, :answer_code
    
  def initialize_from_xml(xml_node) 
    super(xml_node)
    self.question_key = xml_node['question_key']
    self.choice_key = xml_node['choice_key']
    self.answer_code = xml_node['answer_code']
    raise "wrong answered value=#{answer_code}" unless ["ok", "ko"].include?(answer_code)
    
  end
  
  def generate_xml(top_node, classname=nil)
    node_answer = super(top_node, classname)
    node_answer['question_key'] = question_key
    node_answer['choice_key'] = choice_key
    node_answer['answer_code'] = answer_code.to_s
    node_answer
  end
  
  def evaluate(quiz_instance) quiz_instance.user_answered?(question_key, choice_key, answer_code) end  

  def to_s() "[#{question_key}, #{choice_key}, #{answer_code}]" end

  # return a list of tupples [question_key, choice_key
  def get_questionkey_choicekey_involved() [[question_key, choice_key]] end

end

# ----------------------------------------------------------------------------------------
# Idee de PH
# ----------------------------------------------------------------------------------------

# generate choices of questions => ph deduction
# doesn't inherit from Model (therefore o keys)
class GeneratorChoice
    
  def generate_forced_choices() raise "should not be call" end
  
end

# ----------------------------------------------------------------------------------------
# Recommendation
# ----------------------------------------------------------------------------------------

# generate_hash_pkey_weight is a hash of product_key with an associated recommendation weight (-1.00 .. +1.00)
class Recommendation < Model
  # abstract class 
  attr_accessor :weight, :is_reverse
    
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.key = nil
    self.weight = Float(xml_node['weight'])
    self.is_reverse = xml_node['reverse'] == "true"
  end

  def self.create_new_instance_from_xml(xml_node) 
    Pikizi.const_get("Recommendation#{xml_node['type'].capitalize}").new
  end

  def self.create_from_xml(xml_node, knowledge)
    (r = self.create_new_instance_from_xml(xml_node)).initialize_from_xml(xml_node, knowledge); r
  end
  
  def generate_xml(top_node, classname=nil)
    node_recommendation = super(top_node, "recommendation")
    type = self.class.to_s.downcase; type.slice!("pikizi::recommendation")
    node_recommendation['type'] = type
    node_recommendation['weight'] = weight.to_s
    node_recommendation['reverse'] = "true" if is_reverse
    node_recommendation
  end
    
  # generate the weights for the considered products
  # return a hash key product_key -> weight
  def generate_hash_pkey_weight(products) raise "should not be call" end

end

# generate_hash_pkey_weight according to a predicate
class RecommendationPredicate < Recommendation

    attr_accessor :predicate

    def initialize_from_xml(xml_node, knowledge)
      super(xml_node, knowledge)
      self.predicate = xml_node['predicate']
    end

    def generate_xml(top_node, classname=nil)
      node_recommendation_predicate = super(top_node, classname)
      node_recommendation_predicate['predicate'] = predicate
      node_recommendation_predicate
    end

    def generate_hash_pkey_weight(products)
      # interpreting predicate
      # prefix $ means feature key
      # prefix @ means a value for a feature
      evaluable_predicate = RecommendationPredicate.to_ruby_eval(predicate, knowledge_key)

      # select all product that return true for the predicate
      products.inject({}) do |h, product|
        begin
          if eval(evaluable_predicate)
            h[product.key] = weight
          elsif is_reverse
            h[product.key] = -weight
          end
        rescue
          puts "I can't evaluate #{evaluable_predicate}"
        end
        h
      end
    end

    # convert a xml predicate to a string evalable by ruby
    def self.to_ruby_eval(xml_predicate, knowledge_key)
      xml_predicate.split(' ').collect do |t|
        prefix = t[0..0]
        tail = t[1..t.size-1]
        case prefix
          when "$" then tail == "key" ? "product.key" : "product.get_values('#{knowledge_key}', '#{tail}').first"
          when "@" then "'#{tail}'"
          else t
        end
      end.join(' ')
    end

    def to_s() "R @#{predicate}=#{weight}" end

end


# generate_hash_pkey_weight for a given product (or list of products)
class RecommendationProduct < Recommendation
  attr_accessor :product_keys
  
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    raise "eror no produt key for recommendation" unless xml_node['product_key']
    self.product_keys = xml_node['product_key'].split(' ')
  end
  
  def generate_xml(top_node, classname=nil)
    node_recommendation_product = super(top_node, classname)
    node_recommendation_product['product_key'] = product_keys.join(' ')
    node_recommendation_product
  end
  
  def generate_hash_pkey_weight(products)
    products_scope = products.select { |p| product_keys.include?(p.key) }
    products.inject({}) do |h, product|
      if product_keys.include?(product.key)
        h[product.key] = weight
      elsif is_reverse
        h[product.key] = -weight
      end
      h
    end
  end

  def to_s() "@#{product_keys}=#{weight}" end

end

# generate_hash_pkey_weight based on a feature
# select product according to +/- important for a given feature
class RecommendationFpreference < Recommendation
  attr_accessor :feature_key

  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.feature_key = xml_node['feature_key'] 
  end
  
  def generate_xml(top_node, classname=nil)
    node_recommendation_fpreference = super(top_node,  classname)
    node_recommendation_fpreference['feature_key'] = feature_key
    node_recommendation_fpreference
  end
      
  def generate_hash_pkey_weight(products)
    feature = Knowledge.get_model.get_feature_by_key(feature_key)
    products.inject({}) { |h, product| h[product.key] = feature.aggregated_rating(product) * weight; h }
  end  

  def to_s() "pref on feature #{feature_key}" end

end



# describe a collection of products
class Quiz < Root

  attr_accessor :key, :product_keys

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.product_keys = Root.get_collection_from_xml(xml_node, 'product') { |product_key_node| product_key_node['key'] }
  end

  def self.create_with_parameters(key, product_keys)
    quiz = super(key)
    quiz.product_keys = product_keys
    quiz
  end

  def generate_xml(xml_node, class_name=nil)
    node_quiz = super(xml_node, class_name)
    product_keys.each { |pkey| node_quiz << (node_product_key = XML::Node.new('product')); node_product_key['key'] = pkey }
    node_quiz
  end

  def products() @products ||= product_keys.collect {|pkey| Product.get_from_cache(pkey) } end
  
end

class Distribution
  attr_accessor :weight, :proba_ok

  def initialize(weight, proba_ok)
    self.weight = weight
    self.proba_ok = proba_ok
  end

  def to_s() "w=#{weight}#{Root.as_percentage(proba_ok)}" end

  def self.merge_by_weight(distributions)
    distributions.group_by(&:weight).collect do |weight, distributions_bis|
      Distribution.merge_by_weight_bis(distributions_bis)
    end
  end

  def self.merge_by_weight_bis(l, merged=nil)
    if l.size == 0
      merged
    else
      d = l.shift
      if merged
        merged.proba_ok += d.proba_ok
      else
        merged = d
      end
      Distribution.merge_by_weight_bis(l, merged)
    end
  end

  # return the new cumulator
  def self.each_propa_choices(proba_ok, choices, cumul, debug)
    summed_weights = choices.inject({}) do |h, choice|
      choice.generate_hash_pkey_weight.each {|p,w| h[p] ||= 0; h[p] += w } ; h
    end
    PK_LOGGER.info "proba_ok=#{Root.as_percentage(proba_ok)} [#{choices.collect(&:key).join(', ')}] #{summed_weights.inspect}" if debug
    summed_weights.each { |p, w| (cumul[p] ||= []) << Distribution.new(w, proba_ok) }
    cumul
  end

  def self.weighted_average(distributions)
    distributions.inject(0.0)  { |v, d| v += (d.proba_ok * d.weight) }
  end
  
end

end

