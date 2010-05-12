require 'xml'
require 'mongo_mapper'
require 'pidurl2weight'
require 'user'

# =======================================================================================
# Questions
# =======================================================================================

# a question has binary choices... (can be exclusive vs multiple choices)
# a precondition to be askable like has answered x to question y (per default true)
# answers to Question define user clusters
# Question/Answer can be set-up, from already existing customer profile data

class Question < Root


  include MongoMapper::Document


  key :idurl, String # unique url
  key :label, String, :required => true  # text


  key :knowledge_id, BSON::ObjectID
  
  key :knowledge_idurl, String


  key :is_choice_exclusive, Boolean
  key :extra, String
  key :dimension, String

  key :url_image, String
  key :url_description, String

  key :precondition, String
  key :nb_presentation, Integer, :default => 0
  key :nb_oo, Integer, :default => 0
  key :weight, Float  # the weight of the question
  key :distribution_avg_weight, Hash
  key :distribution_deviation, Hash

  many :choices, :polymorphic => true
  def all_choices() @all_choices ||= (choices.collect { |c| c.question = self; c }) end
  
  timestamps!


  # load a question object from an idurl  or a mongo db_id
  def link_back() choices.each { |choice| choice.link_back(self) } end


  # read and create question objects from xml
  def self.initialize_from_xml(knowledge, xml_node)
      question = super(xml_node)
      question.knowledge_idurl = knowledge.idurl
      question.is_choice_exclusive = (xml_node['is_exclusive'] == 'true' ? true : false)
      question.extra = xml_node['extra']
      question.dimension = xml_node['dimension'] || "unknown"
      question.weight = Float(xml_node['weight'] || 1.0)
      question.precondition = xml_node['precondition']
      question.read_xml_list(xml_node, "Choice")
      question.save
  end

  def is_filter() extra == "filter" end
  def is_polling() extra == "polling" end


  # compute and store Pidurl2Weight for each choice of this question
  def generate_choices_pidurl2weight(knowledge)
    products = knowledge.products
    choices.each { |choice| choice.generate_pidurl2weight(products, self, knowledge) }
    compute_distribution
    save
  end

  # compute a Pidurl2Weight
  # weight if the probability of "extra points" for a given product/question
  # weight = question_weight * (...)
  def compute_distribution
    self.distribution_avg_weight = {}
    self.distribution_deviation = {}
    if is_choice_exclusive
      choices.collect do |choice|
        delta_weight([choice]).each do |pidurl, product_weight|
          compute_distribution_bis(pidurl, product_weight * choice.proba_ok)
        end
      end
    else
      l = choices.clone
      Array.combinatorial(l, false) do |combination_choices|
        # combination is a list of choices
        choice_probability = l.inject(1.0) { |x, c| x *= (combination_choices.include?(c) ? c.proba_ok : c.proba_ko) }
        delta_weight(combination_choices).each do |pidurl, product_weight|
          compute_distribution_bis(pidurl, product_weight * choice_probability)
        end
      end
    end
    distribution_deviation.each { |pidurl, weights| distribution_deviation[pidurl] = weights.stat_standard_deviation }
  end

  def compute_distribution_bis(pidurl, x)
    distribution_avg_weight[pidurl] ||= 0; distribution_avg_weight[pidurl] += x
    (distribution_deviation[pidurl] ||= []) << x
  end


  # this function  returns a measure of how the answer to a question will discrimate
  # a set of products
  # the measure is a 3-upple made of [standard deviation, nb product, average weight]
  def discrimination(user,  product_idurls)
    raise "error" unless product_idurls.is_a?(Array) and product_idurls.size > 0
    weights = []; deviations = []
    product_idurls.each do |pidurl|
      weights << (distribution_avg_weight[pidurl] || 0.0)
      deviations << (distribution_deviation[pidurl] || 0.0)
    end
    [weights.stat_standard_deviation * weight, deviations.stat_mean * weight, weights.nb_unique]
  end

  def generate_xml(top_node)
    node_question = super(top_node)
    node_question['is_exclusive'] = is_choice_exclusive.to_s
    node_question['nb_presentation'] = nb_presentation.to_s
    node_question['precondition'] = precondition if precondition
    node_question['extra'] = extra if extra
    node_question['dimension'] = dimension
    node_question['weight'] = weight.to_s

    Root.write_xml_list(node_question, choices)
    node_question
  end

  def nb_choices() @nb_choices ||= choices.size end
  def default_choice_proba_ok() is_choice_exclusive ? 1.0 / nb_choices.to_f : 0.5 end


  # based on precondition expression
  # todo precondition
  def is_askable?(quizze_instance)
    if precondition
      # to be completed
    else
      true
    end
  end

  # define the proba of no opinion 0.0 .. 1.0
  def proba_oo(user=nil) nb_presentation == 0.0 ? 0.0 : (nb_oo /  nb_presentation) end
  def confidence() choices.collect(&:confidence).min end

  # get choice objects from their idurl
  def get_choice_ok_from_idurls(choices_idurls_selected_ok)
    choices.find_all { |choice| choice if choices_idurls_selected_ok.include?(choice.idurl) }
  end

  def get_choice_from_idurl(choice_idurl) choices.detect {|c| c.idurl == choice_idurl } end

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
    save
  end

  # return the incremental value for each product following a choice
  # choices_ok is either a list of choices, an answer, a list of choice_idurls
  # return a Pidurl2Weight object
  def delta_weight(choices_ok)
    if choices_ok.is_a?(Answer)
      choices_ok = get_choice_ok_from_idurls(choices_ok.choice_idurls_ok)
    elsif !choices_ok.first.is_a?(Choice)
      choices_ok = get_choice_ok_from_idurls(choices_ok)
    end
    choices_ok.inject(Pidurl2Weight.new) { |h, choice_ok| h.sum(choice_ok.pidurl2weight) }.normalize!
  end

  # sort the questions by criterions
  def self.sort_by_discrimination(questions, product_idurls, user)
    questions_with_discrimination = questions.collect { |q| [q, q.discrimination(user, product_idurls)] }
    # sort according to the discrimination of this question (i.e. a tupple [standard deviation, size, mean]) for this product space
    # <=> on an array works hierarchyly, ruby is really fantastic !
    question_with_discrimination_sorted = questions_with_discrimination.sort! { |q1, q2| q2.last <=> q1.last }
    question_with_discrimination_sorted.collect(&:first)
  end




  def to_html(choices_ok=[])
    label << "<small style='margin-left:3px'>(#{is_choice_exclusive ? 'exclusive' : 'multiple'})" << "&nbsp;[" << choices.collect {|choice| choices_ok.include?(choice) ? "<b>#{choice.label}</b>" : "#{choice.label}"}.join(', ') << "]</small>"
  end

end

# ----------------------------------------------------------------------------------------
# Choices for a Question
# ----------------------------------------------------------------------------------------

# model a binary variable. true, false
class Choice < Root

  include MongoMapper::EmbeddedDocument

  key :idurl, String # unique url

  key :label, String # text

  key :url_image, String
  key :url_description, String
  key :recommendation, String, :default => nil
  key :intensity, Float
  key :nb_ok, Integer, :default => 0

  key :pidurl2weight, Pidurl2Weight


  attr_accessor :question

  def link_back(question)
    self.question = question
  end


  def nb_ko() @nb_ko ||= (question.nb_presentation - question.nb_oo - nb_ok) end
  def proba_ok() @proba_ok ||= (question.nb_presentation == 0 ? question.default_choice_proba_ok : (nb_ok.to_f / question.nb_presentation.to_f)) end
  def proba_ko() @proba_ko ||= (1.0 - proba_ok - question.proba_oo) end

  NB_ANSWERS_4_MAX_CONFIDENCE = 5.0
  # confidence on proba
  def confidence() [NB_ANSWERS_4_MAX_CONFIDENCE, nb_ok + nb_ko].min / NB_ANSWERS_4_MAX_CONFIDENCE end

  def self.initialize_from_xml(xml_node)
    choice = super(xml_node)
    choice.intensity = Evaluator.intensity2float(xml_node['intensity'] || "very_high")
    choice.recommendation = xml_node['recommendation']
    choice
  end

  def generate_xml(top_node)
    node_choice = super(top_node)
    node_choice['nb_ok'] = nb_ok.to_s
    node_choice['recommendation'] = recommendation if recommendation
    node_choice['intensity'] = intensity.to_s
    node_choice
  end

  # record a choice by a user
  def record_answer(user, reverse_mode) self.nb_ok += (reverse_mode ? -1.0 : +1.0) end

  # initialize the hash_pidurl2weight_cache for this choice
  # this is call from question
  # it's interpret the preference string
  # generate the weights for the considered products
  # return a Pidurl2Weight object
  def generate_pidurl2weight(products, question, knowledge)
    self.pidurl2weight = Evaluator.eval(knowledge, question, products, recommendation, intensity)
    pidurl2weight.check_01
    raise "wrong type=#{pidurl2weight.class}" unless pidurl2weight.is_a?(Pidurl2Weight)
  end


  def generate_javascript_weights(products)
    js_string = ""
    pidurl2weight.check_01
    pidurl_with_weights = pidurl2weight.collect do |pidurl, weight|
      js_string << generate_javascript_weights_bis(pidurl, weight)
      pidurl
    end
    products.each do |product|
      pidurl = product.idurl
      js_string << generate_javascript_weights_bis(pidurl) unless pidurl_with_weights.include?(pidurl)
    end
    js_string
  end
  def generate_javascript_weights_bis(pidurl, weight=nil) "tr_arrow('#{pidurl}','" << (weight ? weight.to_s : "&nbsp;") << "');" end

  def path_image(knowledge_idurl, question_idurl)
    path = "/domains/#{knowledge_idurl}"
    if url_image and url_image != ""
      "#{path}/questions/#{question_idurl}/#{url_image}"
    else
      "#{path}/knowledge/default_image.jpg"
    end

  end

  # =======================================================================================
  # Begin evaluator (to interpret script language)
  # ---------------------------------------------------------------------------------------



  class Evaluator

    attr_accessor :selected_product, :knowledge

    def initialize(knowledge)
      @knowledge = knowledge
    end

    # return a hash product_idurl -> weight
    def self.eval(knowledge, question, products, recommendation, intensity)
      pidurl2weight = Pidurl2Weight.new
      if recommendation
        evaluator = Evaluator.new(knowledge)
        products.each do |product|
          evaluator.selected_product = product
          begin
            value = evaluator.instance_eval(recommendation)
          rescue Exception => e
            puts "***** OUPS I can't evaluate #{recommendation} in question #{question.idurl} for product #{product.idurl} : #{e.message}"
            value = nil
          end

          unless value.nil?
            if value == true or value == false
              value = (value == true ? Evaluator.intensity2float("very_high") : Evaluator.intensity2float("very_low"))
            end
            raise "error value=#{value} intensity=#{intensity} recommendation=#{recommendation}" unless value.is_a?(Float) and value >= 0.0 and value <= 1.0
            value *= intensity
            pidurl2weight.set(product.idurl, value)
            pidurl2weight.check_01
            puts "evaluating product=#{product.idurl} against #{recommendation} --> value=#{value}"
          end
        end
      end
      pidurl2weight
    end

    # ---------------------------------------------------------------------------------------
    # Predicate -> return a logical value (true, false)
    # could be combined with logical operator and
    # ---------------------------------------------------------------------------------------

    # productIs(:iphone_3g)
    # productIs(:any => [:iphone_3g, :iphone_3gs])
    def productIs(options)
      if options.is_a?(Hash)
        key, values = check_hash_options(options, [:any])
        raise "#{values.inspect} => should be an array with at least 1 values" unless values.is_a?(Array) and values.size > 0
        values = check_list_string(values)
        ensure_boolean(values.include?(selected_product.idurl))
      elsif options.is_a?(String) or options.is_a?(Symbol)
        productIs(:any => [options.to_s])
      else
        raise "wrong syntax"
      end
    end

    # featureIs(:brand, :nokia)       // FeatureTags
    # featureIs(:surname, "droid")   // FeatureText
    # featureIs(:has_camera, true)   // FeatureCondition
    # featureIs(:release_date, "12/1/2") // follow format
    # featureIs(:format_audio, :all => [:mp3, :mp4]) // FeatureTags
    # featureIs(:brand, :any => [:nokia, :apple])  // FeatureTags
    # featureIs(:nb_pixel_camera, :moreThan => 2)
    # featureIs(:nb_pixel_camera, :lessThan => 4)
    # featureIs(:nb_pixel_camera, :in => [2.1, 4.5])
    # featureIs(:nb_pixel_camera, :is => 2)
    # featureIs(:nb_pixel_camera, :atLeast => 2)
    # featureIs(:nb_pixel_camera, :atMost => 4)
    #
    # expect selected_product in context
    def featureIs(idurl_feature, options)
      idurl_feature = idurl_feature.to_s if idurl_feature.is_a?(Symbol)
      feature = knowledge.get_feature_by_idurl(idurl_feature)
      raise "error feature #{idurl_feature.inspect} #{idurl_feature.class} doesn't exist in model" unless feature

      if options.is_a?(Hash)
        key, values = check_hash_options(options, [:all, :any, :moreThan, :lessThan, :in, :is, :atLeast, :atMost])
        if feature_value = feature.get_value(selected_product)
          case key
            when :all
              raise "error: expecting a FeatureTags" unless feature.is_a?(FeatureTags)
              values = check_list_string(values)
              ensure_boolean(feature_value.all? { |fv| values.include?(fv) })
            when :any
              raise "error expecting a FeatureTags" unless feature.is_a?(FeatureTags)
              values = check_list_string(values)
              ensure_boolean(feature_value.any? { |fv| values.include?(fv) })
            when :moreThan
              raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
              raise "error" unless values.size == 1
              ensure_boolean(feature_value > convert(feature, values.first))
            when :lessThan
              raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
              raise "error" unless values.size == 1
              ensure_boolean(feature_value < convert(feature, values.first))
            when :in
              raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
              raise "error" unless values.size == 2
              min, max = convert(feature, values.first), convert(feature, values.last)
              ensure_boolean((feature_value >= min and feature_value <= max))
            when :is
              raise "error" unless values.size == 1
              ensure_boolean(feature_value == values.first)
            when :atLeast
              raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
              raise "error" unless values.size == 1
              ensure_boolean(feature_value >= convert(feature, values.first))
            when :atMost
              raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
              raise "error" unless values.size == 1
              ensure_boolean(feature_value <= convert(feature, values.first))
          end
        end
      elsif options.is_a?(String) or options.is_a?(Symbol)
        featureIs(idurl_feature, :any => [options.to_s])
      elsif feature.is_a?(FeatureCondition) and (options.is_a?(FalseClass) or options.is_a?(TrueClass))
        featureIs(idurl_feature, :is => [options.to_s])
      else
        raise "wrong syntax"
      end
    end

    # ---------------------------------------------------------------------------------------
    # Preference -> return a  value [0..1]
    # can be combined with arithmetic operators (+, -, *, /) and parenthesis
    # ---------------------------------------------------------------------------------------
    #

    # maximizeFeature(idurl_feature)
    def maximize(idurl_feature)
      idurl_feature = idurl_feature.to_s if idurl_feature.is_a?(Symbol)
      feature = knowledge.get_feature_by_idurl(idurl_feature)
      raise "#{idurl_feature} doesn't belong to model" unless feature
      feature.get_value_01(selected_product)
    end

    def minimize(idurl_feature) 1.0 - maximize(idurl_feature) end

    # combine(maximize(:price), minimize(:weight))
    def combine(*weights) weights.inject(0.0) { |s,w| s += w } / weights.size.to_f end

    # ----------------------------------------------------------------------------------------
    # not part of the language (private)


    def self.intensities() { "very_high" => 1.0, "high" => 0.75, "medium" => 0.5, "low" => 0.25, "very_low" => 0.0 } end
    def self.intensity2float(i)
      i = i.to_ if i.is_a?(Symbol)
      Evaluator.intensities[i]
    end
    def self.float2intensity(i)
      closest_name, closest_distance = nil, nil
      Evaluator.intensities[i].each do |name, intensity|
        new_distance = (intensity - i).abs
        closest_name, closest_distance = k, new_distance if closest_distance.nil? or closest_distance > new_distance
      end
      closest_name
    end

    def check_hash_options(options, operators)
      raise "wrong syntax" unless options.size == 1
      key, values = options.collect.first
      values = [values] unless values.is_a?(Array)
      values = values.collect {|x| x.is_a?(Symbol) ? x.to_s : x }
      raise "key should be #{operators.join(', ')}" unless operators.include?(key)
      [key, values]
    end

    def check_list_string(l)
      raise "error not a list of string #{l.inspect}" unless l.all? {|v| v.is_a?(String) }
      l
    end


    def convert(feature, value)
      feature.is_a?(FeatureDate) ? FeatureDate.xml2date(value) : Float(value)
    end

    def ensure_boolean(b) b ? true : false end

  end

  # ---------------------------------------------------------------------------------------
  # END evaluator
  # =======================================================================================



end






