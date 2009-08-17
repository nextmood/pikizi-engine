require 'pkz_xml.rb'
require 'pkz_authored.rb'

module Pikizi


# The root of all objects of the model (Feature, Question, Choice, ...)
# Aggregated value (background)

class Model < Root
  # abstract class 
  
  attr_accessor :knowledge, :hash_key_best_background
    
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node)
    self.knowledge = knowledge
    self.key ||= "model##{knowledge.new_index}"
    @hash_key_best_background = Root.get_hash_from_xml(xml_node, 'aggregation', 'key') { |node_aggregation|  Aggregation.create_from_xml(node_aggregation) }

  end       

  def generate_xml(top_node, class_name)
    node_model = super(top_node, class_name)
    @hash_key_best_background.each { |key, aggregation_best_background| aggregation_best_background.generate_xml(node_model) }
    node_model
  end

  def knowledge_key() knowledge.key end
  
  def self.create_from_xml(xml_node, knowledge)
    (x = self.create_new_instance_from_xml(xml_node)).initialize_from_xml(xml_node, knowledge); x
  end

  # return a hash background_key, background object
  def get_backgrounds()
    {}
  end

end

# =======================================================================================
# Describe a hierarchy of features
# =======================================================================================

class Feature < Model
  # abstract class 
  
  attr_accessor :feature_parent, :sub_features, :ratable

  def initialize_from_xml(xml_node, feature_parent) 
    super(xml_node, feature_parent ? feature_parent.knowledge : self)
    self.feature_parent = feature_parent
    self.ratable = (xml_node['ratable'] ? true : nil)
    self.sub_features = Root.get_collection_from_xml(xml_node, "sub_features/feature") { |node| Feature.create_from_xml(node, self) }
    knowledge.hash_key_feature[key] = self
  end

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
    node_feature['ratable'] = "true" if ratable
    if sub_features and sub_features.size > 0      
      node_feature << (node_sub_features = XML::Node.new('sub_features'))
      sub_features.each { |sf| sf.generate_xml(node_sub_features) }
    end
    node_feature
  end

  # translate to html
  def to_html(product, extra, deep_down)

    # backgrounds for knowledege feature
    html_node = (backgrounds_knowledge_feature = get_backgrounds).size > 0 ? "<a href='/knowledges/backgrounds/#{knowledge.key}/#{self.key}'  >...</a>" : ""

    if feature_parent
      html_node << "<span class='pkz_feature_label'>#{label}</span>"
      html_node << "<span class='pkz_feature_extra'>#{extra}</span>"
      html_node << get_html_editor(product)
    else
      html_node << (product ? product.label : "product")
    end

    # rating icon only when product and ratable
    if ratable
      if product
        if opinion_average_expert_rating = get_opinion(product, "average_expert_rating")
          html_node <<  "<span class='pkz_rating' title='average expert rating'>"  << ("%3d" % (opinion_average_expert_rating * 100)) << "%</span>"
        else
          html_node <<  "<span class='pkz_rating' title='average expert rating'>&nbsp;?&nbsp;</span>"
        end
      else
       html_node << "&nbsp;<img src='/images/icons/star.png' title='average expert rating' />"  and product.nil?
      end
    end


    # backgrounds for knowledege feature value
    if product and (backgrounds_knowledge_feature = get_backgrounds(product)).size > 0
      html_node << "&nbsp;<a href='/knowledges/backgrounds/#{knowledge.key}/#{self.key}/#{product.key}'  >...</a>"
    end  

    s_options = (deep_down and sub_features) ? sub_features.collect { |f| "<li>#{f.to_html(product, extra, deep_down)}</li>" } : []
    s_options = (s_options.size > 0) ? "<ul>#{s_options}</ul>" : nil
    "#{html_node}#{s_options}"
  end

  def get_html_editor(product)
    product ? "<input type='text' value='#{value2string(get_value(product))}' />" : "N/A"
  end

  def label_hierarchical() feature_parent ? "#{feature_parent.label_hierarchical}/#{label}" : label  end


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

  # return the aggregated FeatureValue(s) for a product
  # return nil, if no value
  def get_value(product)
    v = product.get_value(knowledge_key, key)
    string2value(v) if v
  end

  # set the feature value for a product
  # you can't set the value to nil (use empty_value instead)
  def set_value(product, user, value_authored)
    raise "atom #{value_authored} has no key" unless value_authored.key
    raise "value #{value_authored.value.inspect} in not in domain of #{self.class}" unless is_valid_value?(value_authored.value)
    product.set_value(value_authored, user, knowledge_key, key)
  end


  # ------------------------------------------------------------------------------------------
  # manage the opinion for a given feature / product
  # ------------------------------------------------------------------------------------------

  def set_opinion(product, user, new_opinion) product.set_opinion(new_opinion, user, knowledge_key, key) end
  def get_opinion(product, opinion_key) product.get_opinion(knowledge_key, key, opinion_key) if product end
  def get_opinions(product)
    raise "product expected" unless product
    product.get_opinions(knowledge_key, key)
  end

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

  # this will return an ActiveRecord background object
  def get_background(product, background_key)
    ar_background = Background.get_from_key(knowledge_key, key, background_key)
    if product
      product.get_background(knowledge_key, key, background_key)
    else
      # TODO return background for feature (no product)   
    end
  end

  # return a hash of background_key => background objects
  def get_backgrounds(product=nil)
    if product
      product.get_backgrounds(knowledge_key, key)
    else
      # TODO return backgrounds for feature (no product)
      {}
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
    self.product_keys = Root.get_collection_from_xml(xml_node, 'products/product') { |node_product| node_product.attributes["key"] }
    self.questions = Root.get_collection_from_xml(xml_node, 'questions/question') { |node_question| Question.create_from_xml(node_question, self) }
    if node_quizzes = xml_node.find_first('feature') and xml_node.find_first('quiz')
      self.quizzes = Root.get_collection_from_xml(xml_node, 'quizzes/quiz') { |node_quiz| Quiz.create_from_xml(node_quiz, self) }
    else
      self.quizzes = [Quiz.create_with_parameters(key, product_keys)]
    end

  end

  def self.get_from_cache(knowledge_key, reload=nil)
    Rails.cache.fetch("M#{knowledge_key}", :force => reload) { Knowledge.create_from_xml(knowledge_key) }
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
    products.each { |product|  node_product_keys << (node_product_key = XML::Node.new('product')); node_product_key["key"] = product.key }
    node_knowledge << (node_quizzes = XML::Node.new('quizzes'))
    quizzes.each { |quiz| quiz.generate_xml(node_quizzes) }
    node_knowledge
  end

  # translate to html
  def to_html(product=nil)
    raise "product class wrong=#{product.inspect}" if product and !product.is_a?(Pikizi::Product)
    hidden_tail = ""
    hierarchy = super(product, nil, true)
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

  # sort the questions by separation desc

  def questions_sorted_by_separation(products, user) questions.sort! { |q1, q2| q2.separation(products, user) <=> q1.separation(products, user) } end

  # return the number of questions handled by this model
  def nb_quizzes() quizzes.size end

  # return the number of recommendations handled by this model
  def nb_recommendation() questions.inject(0) { |s, q| s += q.nb_recommendation } end

  # cancel the recommendations generated by a previous answer
  def cancel_recommendations(last_answer, quiz_instance, products)
    tips_triggered = tips.find_all { |tip| tips_keys_triggered.include?(tip.key) }
    question = get_question_from_key(last_answer.question_key)
    choices_ok = question.choices.find_all { |c| last_answer.choice_keys_ok.include?(c.key) }
    propagate_recommendations(choices_ok, quiz_instance.hash_pkey_affinity, products, true)
  end

  # propagate the recommendations associated with the choices_ok
  # update hash_pkey_affinity ( a hash table between a product-key and and a user affinity)
  def propagate_recommendations(choices_ok, hash_pkey_affinity, products, reverse_mode)
    choices_ok.each do |choice_ok|
      choice_ok.generate_hash_pkey_tensor(products).each do |pkey, tensor|
        hash_pkey_affinity[pkey].add_tensor(tensor, reverse_mode)
      end
    end
  end

  # return a new affinity list
  def trigger_tips(quiz_instance, question, products, choices_ok, simulation)

    choice_keys_ok = choices_ok.collect(&:key)
    answer = quiz_instance.record_answer(question.key, choice_keys_ok)

    hash_pkey_affinity = quiz_instance.hash_productkey_affinity
    hash_pkey_affinity = hash_pkey_affinity.inject({}) { |h, (pkey, a)| h[pkey] = a.clone } if simulation


    propagate_recommendations(choices_ok, hash_pkey_affinity, products, false)

    quiz_instance.cancel_answer(answer) if simulation


    hash_pkey_affinity

  end

  def get_question_from_key(q_key) questions.detect { |q| q.key == q_key } end

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
  
  def to_html(product, extra, deep_down)
    extra = feature_binaries.collect { |sf| sf.label }.join(", ")  unless product
    super(product, extra, false)
  end

  def get_html_editor(product)
    product ? feature_binaries.collect { |sf| sf.get_html_editor(product) }.join(", ") : ""  
  end

  # the value is the list of feature tag-keys with a value set to true
  def get_value(product)
    feature_binaries.inject([]) { |l, sf| v = sf.get_value(product); v == true ? l << sf.key : l }
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
  def get_value(product) [feature_min.get_value(product), feature_max.get_value(product)] end
  
  
  # value is an array of 2 values
  def is_valid_value?(value)
    raise "error" unless value.is_a?(Array) and value.size == 2
    value_min, value_max = value.min, value.max
    feature_min.is_valid_value?(value_min) and feature_max.is_valid_value?(value_max)
  end

  def get_html_editor(product)
    if product
      min, max = get_value(product)
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
      "<input type='#{type_button}'   name='feature_#{key}' value='#{key}' #{(get_value(product) == true) ? 'checked' : nil} />#{label}" 
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

  attr_accessor :is_choice_exclusive, :choices, :precondition_expression, :nb_presentation, :nb_oo
  
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.is_choice_exclusive = (xml_node['is_exclusive'] == 'true' ? true : false)
    self.nb_presentation = Float(xml_node['nb_presentation'] || 0.0)
    self.nb_oo = Float(xml_node['nb_oo'] || 0.0)
    self.choices = Root.get_collection_from_xml(xml_node, "choice") { |node_choice| Choice.create_from_xml(node_choice, knowledge, self) }
    node_expression = xml_node.find_first('if/expression')
    self.precondition_expression = (Expression.create_from_xml(node_expression) if node_expression)
  end
  
  
  def generate_xml(top_node, classname=nil)
    node_question = super(top_node, classname) 
    node_question['is_exclusive'] = is_choice_exclusive.to_s
    node_question['nb_presentation'] = nb_presentation.to_s
    node_question['nb_oo'] = nb_oo.to_s
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
   self.nb_presentation += increment
    if choices_ok.size == 0
      # this is a no opinion
      self.nb_oo += increment
    else
      choices_ok.each { |choice| choice.record_answer(user, reverse_mode) }
    end
  end

  def nb_presentation_valid() nb_presentation - nb_oo end
  
  # compute how this question is discriminating for this user's clsuter
  # return a 0.0 .. 1.0
  # if user is not given, compute the global discrimination
  def discrimination(user=nil)
    if is_choice_exclusive
      # to write for exclusive choices
      #choices.collect { |choice| choice.discrimination(user) }
      -9.99
    else
      # non exclusive choices
      choices_discriminations_sorted_ascending = choices.collect { |choice| choice.discrimination(user) }.sort!
      magnitute_order = 1.0
      sum_discrimination = 0.0
      for i in 0 .. choices_discriminations_sorted_ascending.size - 1
        sum_discrimination += (magnitute_order * choices_discriminations_sorted_ascending[i])
        magnitute_order *= 10.0
      end
      sum_discrimination / magnitute_order # this could theoratically > 1
    end
  end

  # compute the separation factor of each question
  def separation(products, user=nil)
    if is_choice_exclusive
      # separation is the max of each separation
      choices.collect { |choice| choice.separation(products, user) }.max
    else
      # sepration is the sum of each separation
      choices.inject(0.0) { |sum, choice| sum += choice.separation(products, user) }
    end
  end
  
  # define the proba of no opinion 0.0 .. 1.0
  def proba_oo(user=nil) @nb_presentation == 0.0 ? 0.0 : (@nb_oo /  @nb_presentation) end     
  def proba_valid(user=nil) 1.0 - proba_oo(user) end
  def confidence() choices.collect(&:confidence).min end

  # get choice objects from their key
  def get_choice_ok_from_keys(choices_keys_selected_ok)
    choices.find_all { |choice| choice if choices_keys_selected_ok.include?(choice.key) }
  end
  
end


# ----------------------------------------------------------------------------------------
# Choices for a Question
# ----------------------------------------------------------------------------------------

# model a binary variable. true, false
class Choice < Model

  attr_accessor :nb_ok, :is_choice_exclusive, :recommendations, :question
  
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.is_choice_exclusive = (xml_node['is_choice_exclusive'] == 'true' ? true : false)
    self.recommendations = Root.get_collection_from_xml(xml_node, 'recommendations/recommendation') { |node_recommendation| Recommendation.create_from_xml(node_recommendation, knowledge) }
    self.nb_ok = Float(xml_node['nb_ok'] || 0.0)

  end

  def self.create_from_xml(node_xml, class_name, question)
    choice = super(node_xml, class_name)
    choice.question = question
    choice
  end

  def generate_xml(top_node, classname=nil)
    node_choice = super(top_node, classname) 
    node_choice['is_choice_exclusive'] = is_choice_exclusive.to_s
    node_choice['nb_ok'] = nb_ok.to_s
    node_choice << (node_recommendations = XML::Node.new('recommendations'))
    recommendations.each { |recommendation| recommendation.generate_xml(node_recommendations) }
    node_choice
  end

  def nb_ko() question.nb_presentation_valid - nb_ok end

  NB_ANSWERS_4_MAX_CONFIDENCE = 5.0
  # confidence on proba
  def confidence() [NB_ANSWERS_4_MAX_CONFIDENCE, nb_ok + nb_ko].min / NB_ANSWERS_4_MAX_CONFIDENCE end

  #TODO how to introduce the user variable?
  # proba that a user choose this choice
  # doesn't make sense for a question already answered
  # this the entry point for thibault's algorithm
  def proba_ok(user=nil) (sum = nb_ok + nb_ko) == 0 ? question.default_choice_proba_ok : nb_ok / sum end   
  def proba_ko(user=nil) 1.0 - proba_ok(user) end

  # return a discrimination factor
  # if proba(user) == 0.5 returns 1.0
  # if proba(user) == 0.0 or 1.0 returns 0.0
  # if user is nil returns the discrimantion global
  def discrimination(user=nil) 1.0 - ((proba_ok(user) - 0.5).abs * 2.0) end

  # describe a separation factor (between 0 and 1)
  # 1 means that if a user answer ok to this choice, this will separate highly separate/discriminate the considered products
  # 0 means that if a user answer ok tthere is no change in ranking these products
  def separation(products, user=nil)
    # right now, this is global (the user variable is for later)
    hash_pkey_tensor = generate_hash_pkey_tensor(products, true) # generate with fake tensor
    hash_weight_tensors = hash_pkey_tensor.group_by { |pkey, tensor| tensor.weight }
    if hash_weight_tensors.size >= 2
      # build each asymetric pair or values
      separation_sum = 0.0
      hash_weight_tensors.each_with_index do |(value1, tensors1), i|
        hash_weight_tensors.each_with_index do |(value2, tensors2), j|
          separation_sum += tensors1.size * tensors2.size * (value1 - value2).abs if j > i
        end
      end
      separation_sum * proba_ok(user)
    else
      0.0
    end
  end


  # record a choice by a user
  def record_answer(user, reverse_mode)
    self.nb_ok += (reverse_mode ? -1.0 : +1.0)
  end


  # return a hash product_key -> list of tensors object
  # option add_null_tensor, add all products with no tensor generated
  def generate_hash_pkey_tensor(products, add_null_tensor=false)
    hash_pkey_tensor = recommendations.inject({}) do |h, recommendation|
      recommendation.generate_hash_pkey_tensor(products).each do |pkey, tensor|
        existing_tensor = h[pkey]
        h[pkey] = existing_tensor ? existing_tensor.merge(tensor) : tensor    
      end
      h
    end
    products.each { |product| hash_pkey_tensor[product.key] ||= Tensor.new(product, 0.0) } if add_null_tensor
    hash_pkey_tensor
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


# generate_hash_pkey_tensor is a hash of product_key with an associated recommendation tensor (-1.00 .. +1.00)
class Recommendation < Model
  # abstract class 
  attr_accessor :weight
    
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.weight = Float(xml_node['weight'])
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
    node_recommendation
  end
    
  # generate the Tensors for the considered products
  # return a hash key product_key -> a list of Tensor object
  def generate_hash_pkey_tensor(products) raise "should not be call" end

end

# generate_hash_pkey_tensor for a given product
class RecommendationProduct < Recommendation
  attr_accessor :product_key, :mode # preference or filter
  
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.product_key = xml_node['product_key'] 
    self.mode = xml_node['mode']  
  end
  
  def generate_xml(top_node, classname=nil)
    node_recommendation_product = super(top_node, classname)
    node_recommendation_product['product_key'] = product_key
    node_recommendation_product['mode'] = mode
    node_recommendation_product
  end
  
  def generate_hash_pkey_tensor(products)
    product = products.detect { |p| p.key == product_key }
    product ? { product.key => Pikizi.const_get("Tensor#{mode.capitalize}").new(product, weight) } : {}
  end

  def to_s() "#{mode[0..0]}@#{product_key}=#{weight}" end

end

# generate_hash_pkey_tensor based on a feature
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
      
  def generate_hash_pkey_tensor(products)
    feature = Knowledge.get_model.get_feature_by_key(feature_key)
    products.inject({}) { |h, product| h[product.key] = TensorPreference.new(product, feature.aggregated_rating(product) * weight); h }
  end  

  def to_s() "pref on feature #{feature_key}" end

end

# generate_hash_pkey_tensor by filtering products  according to a feature / filter_proc
class RecommendationFfilter < RecommendationFpreference
  attr_accessor :filter_proc
  
  def initialize_from_xml(xml_node, knowledge)
    super(xml_node, knowledge)
    self.filter_proc = xml_node['filter_proc'] 
  end
  
  def generate_xml(top_node, classname=nil)
    node_recommendation_ffilter = super(top_node, classname)
    node_recommendation_ffilter['filter_proc'] = filter_proc
    node_recommendation_ffilter
  end
  
  def generate_hash_pkey_tensor(products)
    feature = Knowledge.get_model.get_feature_by_key(feature_key)
    products.inject({}) do |h, product|
      h[product.key] = TensorFilter.new(product, nil) if value = feature.get_value(product) and filter_proc.call(value)
      h 
    end
  end  

  def to_s() "filter on #{filter_proc.inspect}" end

end

# define an  attraction/repulsion toward a product
class Tensor
  attr_accessor :product, :weight, :nb_merge
  
  def initialize(product, weight)
    self.product = product
    self.weight = weight
    self.nb_merge = 0
  end

  def self.hash_to_s(hash_pkey_tensor)
    hash_pkey_tensor.collect { |pkey, tensor| "#{pkey}=>#{tensor}" }.join(', ')
  end

  def merge(other_tensor)
    raise "error not same type or product key" unless self.class == other_tensor.class and product.key == other_tensor.product.key
    self.nb_merge += 1
    self.weight += other_tensor.weight
    self
  end

  
end

# product get in/out the filtered list 
class TensorFilter < Tensor
  
  def to_s() "TFilt=#{weight}" end

end

class TensorPreference < Tensor

  def to_s() "TPref=#{weight}" end

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


end

class Array

  # this is call on an array of tensor
  def add_tensor(tensors)
    raise "oups parameters" unless self.all? { |x| x.is_a?(Tensor) } and tensors.is_a?(Array) and tensors.all? { |x| x.is_a?(Tensor)}
      stf.add_tensors(tf)
  end
  
end
