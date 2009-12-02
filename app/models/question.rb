require 'xml'
require 'mongo_mapper'


# =======================================================================================
# Questions
# =======================================================================================

# a question has binary choices... (can be exclusive vs multiple choices)
# a precondition to be askable like has answered x to question y (per default true)
# answers to Question define user clusters
# Question/Answer can be set-up, from already existing customer profile data

class Question < Root

  include MongoMapper::Document

  key :idurl, String, :index => true # unique url

  key :label, String, :required => true  # text


  key :is_choice_exclusive, Boolean
  key :is_filter, Boolean
  key :dimension, String

  key :url_image, String
  key :url_description, String

  key :precondition, String
  key :nb_presentation, Integer, :default => 0
  key :nb_oo, Integer, :default => 0
  key :weight, Float

  many :choices, :polymorphic => true

  timestamps!

  attr_accessor :knowledge


  def link_back(knowledge)
    self.knowledge = knowledge
    choices.each { |choice| choice.link_back(self) }
  end

  def self.is_main_document() true end

  # read and create question objects from xml
  def self.initialize_from_xml(knowledge, xml_node)
      question = super(xml_node)
      question.is_choice_exclusive = (xml_node['is_exclusive'] == 'true' ? true : false)
      question.is_filter = xml_node['is_filter']
      question.dimension = xml_node['dimension'] || "unknown"
      question.weight = Float(xml_node['weight'] || 1.0)
      question.precondition = xml_node['precondition']
      question.read_xml_list(xml_node, "Choice")
      question.save
  end

  # compute and store HashProductIdurl2Weight for each choice of this question
  def generate_choices_hash_product_idurl_2_weight
    products = knowledge.products
    choices.each { |choice| choice.generate_hash_product_idurl_2_weight(products) }
    save
  end

  def generate_xml(top_node)
    node_question = super(top_node)
    node_question['is_exclusive'] = is_choice_exclusive.to_s
    node_question['nb_presentation'] = nb_presentation.to_s
    node_question['precondition'] = precondition if precondition
    node_question['is_filter'] = "true" if is_filter
    node_question['dimension'] = dimension
    node_question['weight'] = weight.to_s

    Root.write_xml_list(node_question, choices)
    node_question
  end

  def nb_choices() @nb_choices ||= choices.size end
  def default_choice_proba_ok() is_choice_exclusive ? 1.0 / nb_choices.to_f : 0.5 end

  # return the number of recommendations handled by this question
  def nb_recommendation() choices.inject(0) { |s, c| s += c.nb_recommendation } end

  # based on precondition expression
  # todo precondition
  def is_askable?(quizze_instance)
    if precondition
      # to be completed
    else
      true
    end
  end


  def compute_ab_factors(quizze)
    weight_min, weight_max = nil, nil
    if is_choice_exclusive
      choices.each do |choice|
        weight_min, weight_max = compute_ab_factors_bis(quizze, [choice], weight_min, weight_max)
      end
    else
      Array.combinatorial(choices.clone, false) do |selected_choices|
        weight_min, weight_max = compute_ab_factors_bis(quizze, selected_choices, weight_min, weight_max)
      end
    end
    if weight_min and weight_max and weight_max - weight_min > 0
      a_factor = 1.0 / (weight_max - weight_min)
      b_factor = weight_min * - a_factor
      [a_factor, b_factor, weight_min, weight_max]
    else
      puts "oups -> #{to_s}, weight_min=#{weight_min}, weight_max=#{weight_max}"
      nil
    end

  end

  def compute_ab_factors_bis(quizze, selected_choices, weight_min, weight_max)
    quizze.product_idurls.each do |product_idurl|
      product_weight = selected_choices.inject(0.0) do |s, choice|
        a_weight = choice.hash_product_idurl_2_weight[product_idurl]
        a_weight ? s += a_weight * weight : s
      end
      weight_min = product_weight if weight_min.nil? or weight_min > product_weight
      weight_max = product_weight if weight_max.nil? or weight_max < product_weight
    end
    [weight_min, weight_max]
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

  # this is a collection of the weight distribution for each product (merging choices according to proba)
  # for a given question
  # return for this question, a hash (product_idurl => Distribution)
  # for example: p1 -> [DistributionAtom(20%,-1.0), DistributionAtom(50%,0.5), DistributionAtom(30%,0.2)]
  # meaning is: if this question is asked, there is a probability of
  # 20% of product p1 getting a -1.0, 50% of getting 0.5 etc...
  def products_distribution() @products_distribution ||= ProductsDistribution.new(self) end

  # sort the questions by criterions
  def self.sort_by_discrimination(questions, product_idurls, user)
    questions_with_discrimination = questions.collect { |q| [q, q.discrimination(user, product_idurls)] }
    # sort according to the discrimination of this question (i.e. a tupple [standard deviation, size, mean]) for this product space
    # <=> on an array works hierarchyly, ruby is really fantastic !
    question_with_discrimination_sorted = questions_with_discrimination.sort! { |q1, q2| q2.last <=> q1.last }
    question_with_discrimination_sorted.collect(&:first)
  end


  # this function  returns a measure of how the answer to a question will discrimate
  # a set of products
  # the measure is a 3-upple made of [standard deviation, nb product, average weight]
  def discrimination(user, product_idurls)
    products_distribution.discrimination(user, product_idurls)
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

  key :idurl, String, :index => true # unique url

  key :label, String # text

  key :url_image, String
  key :url_description, String
  key :preference, String
  key :nb_ok, Integer, :default => 0

  key :hash_product_idurl_2_weight_cache, Hash

  attr_accessor :question

  def link_back(question)
    self.question = question
    recommendations.each { |recommendation| recommendation.link_back(self) }
  end

  def knowledge() question.knowledge end

  def nb_ko() @nb_ko ||= (question.nb_presentation - question.nb_oo - nb_ok) end
  def proba_ok() @proba_ok ||= (question.nb_presentation == 0 ? question.default_choice_proba_ok : (nb_ok.to_f / question.nb_presentation.to_f)) end
  def proba_ko() @proba_ko ||= (1.0 - proba_ok - question.proba_oo) end

  NB_ANSWERS_4_MAX_CONFIDENCE = 5.0
  # confidence on proba
  def confidence() [NB_ANSWERS_4_MAX_CONFIDENCE, nb_ok + nb_ko].min / NB_ANSWERS_4_MAX_CONFIDENCE end

  def self.initialize_from_xml(xml_node)
    choice = super(xml_node)
    choice.preference = xml_node['preference']
    choice
  end

  def generate_xml(top_node)
    node_choice = super(top_node)
    node_choice['nb_ok'] = nb_ok.to_s
    node_choice['preference'] = preference
    node_choice
  end

  # record a choice by a user
  def record_answer(user, reverse_mode) self.nb_ok += (reverse_mode ? -1.0 : +1.0) end

  # initialize the hash_product_idurl_2_weight_cache for this choice
  # this is call from question
  def generate_hash_product_idurl_2_weight(products)
    self.hash_product_idurl_2_weight_cache = recommendations.inject(HashProductIdurl2Weight.new) do |h, recommendation|
        h += recommendation.generate_hash_product_idurl_2_weight(products); h
    end.hash_pidurl_weight
  end

  def hash_product_idurl_2_weight
    @hash_product_idurl_2_weight ||= HashProductIdurl2Weight.new(hash_product_idurl_2_weight_cache)
  end

  def generate_javascript_weights(products)
    js_string = ""
    pidurl_with_weights = hash_product_idurl_2_weight.collect do |pidurl, weight|
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

  # return the number of recommendations handled by this question
  def nb_recommendation() recommendations.size end

  # =======================================================================================
  # Begin evaluator (to interpret script language)
  # ---------------------------------------------------------------------------------------

  class Evaluator

    def initialize(product)
      @product = product
    end

    def selected_product() @product end

    # return true or false
    def eval(predicate) self.eval_instance_eval(predicate) end

    # ---------------------------------------------------------------------------------------
    # Predicate -> return a logical value (true, false)
    # could be combined with logical operator and
    # ---------------------------------------------------------------------------------------

    # productIs(:iphone_3g)
    # productIs(:any => [:iphone_3g, :iphone_3gs])
    def productIs(options)
      if options.is_a?(Hash)
        key, values = check_hash(options, [:any])
        raise "#{values.inspect} => should be an array of symbols with at least 2 values" unless values.is_a?(Array) and values.size > 1
        values = check_list_symbol_or_string(values)
        values.include?(selected_product.idurl) ? high : low
      elsif options.is_a?(Symbol) or options.is_a?(String) 
        productIs(:any => [options])
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
    def featureIs(idurl_feature, options)
      if options.is_a?(Hash)
        key, values = check_hash_options(options, [:all, :any, :moreThan, :lessThan, :in, :is, :atLeast, :atMost])
        feature = knowledge.get_feature_by_idurl(idurl_feature)
        feature_value = feature.get_value(selected_product)
        case key
          when :all
            raise "error" unless feature.is_a?(FeatureTags)
            values = check_list_symbol_or_string(values)
            feature_value.all? { |fv| values.include?(fv) } ? very_high : very_low
          when :any
            raise "error" unless feature.is_a?(FeatureTags)
            values = check_list_symbol_or_string(values)
            feature_value.any? { |fv| values.include?(fv) } ? very_high : very_low
          when :moreThan
            raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
            raise "error" unless values.size == 1
            feature_value > convert(feature, values.first)  ? very_high : very_low
          when :lessThan
            raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
            raise "error" unless values.size == 1
            feature_value < convert(feature, values.first) ? very_high : very_low
          when :in
            raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
            raise "error" unless values.size == 2
            min, max = convert(feature, values.first), convert(feature, values.last)
            (feature_value >= min and feature_value <= max) ? very_high : very_low
          when :is
            raise "error" unless values.size == 1
            feature_value == values.first ? very_high : very_low
          when :atLeast
            raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
            raise "error" unless values.size == 1
            feature_value >= convert(feature, values.first) ? very_high : very_low
          when :atMost
            raise "error" unless feature.is_a?(FeatureNumeric) or feature.is_a?(FeatureDate)  or feature.is_a?(FeatureRating)
            raise "error" unless values.size == 1
            feature_value <= convert(feature, values.first) ? very_high : very_low
        end
      elsif options.is_a?(Symbol) or options.is_a?(String)
        featureIs(idurl_feature, :any => [options])
      else
        raise "wrong syntax"
      end
    end

    # ---------------------------------------------------------------------------------------
    # Preference -> return a  value [0..1]
    # can be combined with arithmetic operators (+, -, *, /) and parenthesis
    # ---------------------------------------------------------------------------------------
    #

    # maximizeFeature(feature_idurl)
    # maximizeFeature(feature_idurl, :intensity) where intensity is either :very_low, :low, :medium, :high, :very_high

    def maximize(idurl_feature, intensity = nil)
      intensity ||= very_high
      feature = knowledge.get_feature_by_idurl(idurl_feature)
      feature.get_value_01(selected_product) * intensity
    end

    # ----------------------------------------------------------------------------------------
    # not part of the language (private)

    def very_high() 1.0 end
    def high() 0.75 end
    def medium() 0.5 end
    def low() 0.25 end
    def very_low() 0.0 end


    def check_hash_options(options, operators)
      raise "wrong syntax" unless options.size == 1
      key, values = options.collect.first
      values = values.collect {|x| x.is_a?(Symbol) ? x.to_s : x }
      raise "key should be #{operators.join(', ')}" unless operators.include?(key)
      [key, values]
    end

    def check_list_symbol_or_string(l)
      l.collect do |value|
          case value.class
            when Symbol then value.to_s
            when String then value
            else raise "error"
          end
    end

    def convert(feature, value)
      feature.is_a?(FeatureDate) ? FeatureDate.xml2date(value) : Float(value)
    end

  end

  # ---------------------------------------------------------------------------------------
  # END evaluator
  # =======================================================================================




end


# ----------------------------------------------------------------------------------------
# Recommendation
# ----------------------------------------------------------------------------------------

# generate_hash_product_idurl_2_weight is a hash of product_idurl with an associated recommendation weight (-1.00 .. +1.00)
class Recommendation < Root

  include MongoMapper::EmbeddedDocument

  key :weight, Float
  key :predicate , String

  attr_accessor :choice

  def link_back(choice)
    self.choice = choice
  end

  def knowledge() choice.knowledge end

  def self.initialize_from_xml(xml_node)
    recommendation = super(xml_node)
    recommendation.weight = Float(xml_node['weight'])
    recommendation.predicate = xml_node['predicate']
    recommendation
  end


  def generate_xml(top_node)
    node_recommendation = super(top_node)
    node_recommendation['weight'] = weight.to_s
    node_recommendation['predicate'] = predicate
    node_recommendation
  end

  # this is where theXML predicate is interpreted
  # generate the weights for the considered products
  # return a HashProductIdurl2Weight object
  def generate_hash_product_idurl_2_weight(products)
    # interpreting predicate
    #begin
      tokens = predicate.strip.split(' ').collect(&:strip)

      # -------------------------------------------------------------------------
      # FeatureTag.idurl is Tag.idurl, ... Tag.idurl
      # -------------------------------------------------------------------------
      if tokens[1] == "is:"  and tokens[0] != "product"
        feature_idurl = tokens.shift
        tokens.shift # skip "is:"

        feature = knowledge.get_feature_by_idurl(feature_idurl)
        raise "wrong feature #{feature_idurl} in predicate #{predicate}" unless feature
        raise "feature #{feature_idurl} should be a FeatureTags in predicate #{predicate}" unless feature.is_a?(FeatureTags)
        # check tag idurls
        raise "you need at least one tag in predicate #{predicate}" unless tokens.size > 0
        authorized_tag_idurls = feature.tags.collect(&:idurl)
        tokens.each do |tag_idurl|
          raise "tag #{tag_idurl} doesn't exist for feature #{feature.idurl} in predicate #{predicate}" unless authorized_tag_idurls.include?(tag_idurl)
        end

        products.inject(HashProductIdurl2Weight.new) do |h, product|
          if values = feature.get_value(product)
            # true if product hast at least one of the tokens values
            # puts "h=#{h.inspect} product.idurl=#{product.idurl}"
            if tokens.any? { | tag_idurl | values.include?(tag_idurl) }
              h.add(product.idurl, weight)
            elsif is_reverse
              h.add(product.idurl, -1.0 * weight)
            end
          end
          h
        end

      # -------------------------------------------------------------------------
      # product is Product.idurl, ... Product.idurl
      # -------------------------------------------------------------------------
      elsif tokens[0] == "product" and tokens[1] == "is:"
        tokens.shift # skip "product"
        tokens.shift # skip "is:"
        products.inject(HashProductIdurl2Weight.new) do |h, product|
          if tokens.include?(product.idurl)
            h.add(product.idurl, weight)
          elsif is_reverse
            h.add(product.idurl, -1.0 * weight)
          end
          h
        end
        # write an other predicate here
        # always return a hash product_idurl => weight

      # -------------------------------------------------------------------------
      # other predicate
      # -------------------------------------------------------------------------
      else
        raise "predicate unrecognized #{predicate}"
      end

    #rescue Exception => e
      #puts "*** #{e.message}"
      #nil
    #end
  end


  def to_s() "R @#{predicate}=#{weight}" end

end

# this is a collection of the weight distribution for each product (merging choices according to proba)
# for a given question
# return for this question, a hash (product_idurl => Distribution)
# for example: p1 -> [DistributionAtom(20%,-1.0), DistributionAtom(50%,0.5), DistributionAtom(30%,0.2)]
# meaning is: if this question is asked, there is a probability of
# 20% of product p1 getting a -1.0, 50% of getting 0.5 etc...
# compute also the minimum/maximum weight that this product can get
class ProductsDistribution

  attr_accessor :hash_pidurl_distribution, :question

  def initialize(question)
    @hash_pidurl_distribution = {}
    @question = question
    question.is_choice_exclusive ? initialize_exclusive : initialize_inclusive
  end

  def collect(&block) @hash_pidurl_distribution.collect(&block) end

  # this function  returns a measure of how the answer to a question will discrimate
  # a set of products
  # the measure is a 3-upple made of [standard deviation, nb product, average weight]
  def discrimination(user, product_idurls)
    weights = @hash_pidurl_distribution.inject([]) do |l, (pidurl, distribution)|
      l << distribution.weighted_average * question.weight if product_idurls.include?(pidurl)
      l
    end

    if (size = weights.size) == 0
        [0.0, 0 , 0.0]
    elsif size == 1
        [0.0, 1, weights.first]
    else
        [weights.stat_standard_deviation, weights.size, weights.stat_mean]
    end
  end

  def get_distribution4product_idurl(product_idurl) @hash_pidurl_distribution[product_idurl] end
  # private below


  def initialize_inclusive
    ProductsDistribution.combinatorial_weight(question.choices) do |selected_choices, hash_product_idurl_2_weight, choice_probability|
      hash_product_idurl_2_weight.each do |pidurl, weight|
        distribution = (hash_pidurl_distribution[pidurl] ||= Distribution.new)
        distribution.add(weight, choice_probability)
      end
    end
  end

  def initialize_exclusive
    question.choices.each do |choice|
      choice_probability = choice.proba_ok
      choice.hash_product_idurl_2_weight.each do |pidurl, weight|
        distribution = (hash_pidurl_distribution[pidurl] ||= Distribution.new)
        distribution.add(weight, choice_probability)
      end
    end
  end


  def self.combinatorial_weight(choices, &block)
    hash_combinationkey2hash_product_idurl_2_weight = {}

    Array.combinatorial(choices, false) do |combination_choices|
      # combination is a list of choices
      choice_probability = choices.inject(1.0) { |x, c| x *= (combination_choices.include?(c) ? c.proba_ok : c.proba_ko) }

      combination_choices_new = combination_choices.clone
      combination_key = ProductsDistribution.compute_combination_key(combination_choices_new)
      first_choice = combination_choices_new.shift
      hash_product_idurl_2_weight = first_choice.hash_product_idurl_2_weight
      hash_product_idurl_2_weight += hash_combinationkey2hash_product_idurl_2_weight[ProductsDistribution.compute_combination_key(combination_choices_new)] if combination_choices_new.size > 0
      hash_combinationkey2hash_product_idurl_2_weight[combination_key] = hash_product_idurl_2_weight
      block.call(combination_choices, hash_product_idurl_2_weight, choice_probability)
    end
  end

  def self.compute_combination_key(combination_choices) combination_choices.collect(&:idurl).join end




end

# Distribution is a collection of weight/proba for a given product/question
class Distribution
  attr_accessor :hash_weight_probability

  def initialize()
    @hash_weight_probability = {}
  end

  def add(weight, probability)
    @hash_weight_probability[weight] ||= 0.0
    @hash_weight_probability[weight] += probability
  end

  def weighted_average
    @hash_weight_probability.inject(0.0) { |wa, (weight, probability)| wa += (probability * weight) }
  end


  def to_s()
    "Distribution=[" << @hash_weight_probability.collect {|weight, probability| "#{weight} => #{Root.as_percentage(probability)}"}.join(", ") << "]"
  end


end


# this a hash between Product Idurl and weight
class HashProductIdurl2Weight
  attr_accessor :hash_pidurl_weight

  def initialize(hash_pidurl_weight_initial={}) @hash_pidurl_weight = hash_pidurl_weight_initial end

  def add(product_idurl, weight) @hash_pidurl_weight[product_idurl] = weight end

  def +(other_hash)
    other_hash.hash_pidurl_weight.each do |pidurl, weight|
      @hash_pidurl_weight[pidurl] ||= 0.0
      @hash_pidurl_weight[pidurl] += weight
    end
    self
  end

  # return the weight for a given product_idurl
  def [](product_idurl) @hash_pidurl_weight[product_idurl] end

  def to_s
    "HashProductIdurl2Weight[" << @hash_pidurl_weight.collect { |pidurl, weight| "#{pidurl}:#{'%3.1f' % weight}" }.join(', ') << "]"
  end

  def collect(&block) @hash_pidurl_weight.collect(&block) end

  # proxy
  def each(&block) @hash_pidurl_weight.each(&block) end


end



# extented array with basic statistical functions
class Array

  def stat_sum() inject(0.0) { |s, x| s += x } end
  def stat_mean() stat_sum / size.to_f end
  def stat_standard_deviation()
    m = stat_mean
    Math.sqrt((inject(0.0) { |s, x| s += (x - m)**2 } / size.to_f))
  end

  # yield all all possible combinations in an array
  # and return the number of combination (empty set count for one)
  def self.combinatorial(tail, empty_count, &block) self.combinatorial_bis(tail, empty_count, [], 0, &block) end
  def self.combinatorial_bis(tail, empty_count, elt_set, x, &block)
    if tail.size == 0
      if elt_set.size > 0 or empty_count
        block.call(elt_set)
        x += 1
      else
        x
      end
    else
      new_tail = tail.clone
      first_elt = new_tail.shift
      x = self.combinatorial_bis(new_tail, empty_count, elt_set, x, &block)
      x = self.combinatorial_bis(new_tail, empty_count, elt_set.clone << first_elt, x, &block)
    end
    x
  end

end

