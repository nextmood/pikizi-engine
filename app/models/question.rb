require 'xml'
require 'mongo_mapper'

# =======================================================================================
# Questions
# =======================================================================================

# a question has binary choices... (can be exclusive choices)
# a precondition to be askable (per default true)
# Answers to Question define user cluster
# Question/Answer can be set-up, from already existing customer profile data

class Question < Root

  include MongoMapper::Document

  key :idurl, String, :required => true  # unique url
  key :label, String, :required => true  # text
  many :backgrounds

  key :is_choice_exclusive, Boolean
  key :is_filter, Boolean

  key :precondition, String
  key :nb_presentation, Integer, :default => 0
  key :nb_oo, Integer, :default => 0

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
      question.precondition = xml_node['precondition']
      question.read_xml_list(xml_node, "Choice")
      question.save
  end


  def generate_xml(top_node)
    node_question = super(top_node)
    node_question['is_exclusive'] = is_choice_exclusive.to_s
    node_question['nb_presentation'] = nb_presentation.to_s
    node_question['precondition'] = "true" if precondition
    node_question['is_filter'] = "true" if is_filter
    Root.write_xml_list(node_question, choices)
    node_question
  end

  def nb_choices() @nb_choices ||= choices.size end
  def default_choice_proba_ok() is_choice_exclusive ? 1.0 / nb_choices.to_f : 0.5 end

  # return the number of recommendations handled by this question
  def nb_recommendation() choices.inject(0) { |s, c| s += c.nb_recommendation } end

  # based on precondition expression
  def is_askable?(quiz_instance) precondition ? precondition.evaluate(quiz_instance) : true end


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
  end


  def enumerator(debug = nil)
    e = is_choice_exclusive ? enumerator_exclusive(debug) : enumerator_inclusive(debug)
    PK_LOGGER.debug "---------------------------"  if debug
    result = e.inject({}) do |h, (pidurl, distributions)|
      h[pidurl] = Distribution.merge_by_weight(distributions)
      PK_LOGGER.info "#{pidurl} =>  #{h[pidurl].join(', ')}"  if debug
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


end


# ----------------------------------------------------------------------------------------
# Choices for a Question
# ----------------------------------------------------------------------------------------

# model a binary variable. true, false
class Choice < Root

  include MongoMapper::EmbeddedDocument

  key :idurl, String # unique url
  key :label, String # text
  many :backgrounds

  key :nb_ok, Integer, :default => 0
  many :recommendations, :polymorphic => true

  attr_accessor :question

  def link_back(question)
    self.question = question
    recommendations.each { |recommendation| recommendation.link_back(self) }
  end

  def knowledge() question.knowledge end
  
  def nb_ko() @nb_ko ||= (question.nb_presentation - question.nb_oo - nb_ok) end
  def proba_ok() @proba_ok ||= (question.nb_presentation == 0 ? question.default_choice_proba_ok : nb_ok / question.nb_presentation) end
  def proba_ko() @proba_ko ||= (1.0 - proba_ok - question.proba_oo) end
  
  NB_ANSWERS_4_MAX_CONFIDENCE = 5.0
  # confidence on proba
  def confidence() [NB_ANSWERS_4_MAX_CONFIDENCE, nb_ok + nb_ko].min / NB_ANSWERS_4_MAX_CONFIDENCE end

  def self.initialize_from_xml(xml_node)
    choice = super(xml_node)
    choice.read_xml_list(xml_node, "Recommendation")
    choice
  end

  def generate_xml(top_node)
    node_choice = super(top_node)
    node_choice['nb_ok'] = nb_ok.to_s
    Root.write_xml_list(node_choice, recommendations)        
    node_choice
  end

  # record a choice by a user
  def record_answer(user, reverse_mode) self.nb_ok += (reverse_mode ? -1.0 : +1.0) end

  # return a hash product_idurl -> weight
  # options
  # - :add_null, add a null weight for all products per default
  def generate_hash_pidurl_weight(products=nil, options={})
    if (is_cached = !(products or options[:add_null])) and @hash_pidurl_weight
      @hash_pidurl_weight
    else
      products ||= knowledge.products
      hash_pidurl_weight = recommendations.inject({}) do |h, recommendation|
        recommendation.generate_hash_pidurl_weight(products).each do |pidurl, weight|
          h[pidurl] = (h[pidurl] || 0.0) + weight
        end
        h
      end
      products.each { |product| hash_pidurl_weight[product.idurl] ||= 0.0 } if options[:add_null]
      @hash_pidurl_weight = hash_pidurl_weight if is_cached
      hash_pidurl_weight
    end
  end


  def generate_javascript_weights(products)
    hash_pidurl_weight = generate_hash_pidurl_weight(products, :add_null => true).collect do |pidurl, weight|
      "tr_arrow('#{pidurl}','" << (weight != 0.0 ? weight.to_s : "&nbsp;") << "');"
    end.join(' ')
  end

  # return the number of recommendations handled by this question
  def nb_recommendation() recommendations.size end


end


# ----------------------------------------------------------------------------------------
# Recommendation
# ----------------------------------------------------------------------------------------

# generate_hash_pidurl_weight is a hash of product_idurl with an associated recommendation weight (-1.00 .. +1.00)
class Recommendation < Root

  include MongoMapper::EmbeddedDocument

  key :weight, Float
  key :is_reverse, Boolean

  attr_accessor :choice

  def link_back(choice)
    self.choice = choice
  end

  def knowledge() choice.knowledge end
  
  def self.initialize_from_xml(xml_node)
    recommendation = super(xml_node)
    recommendation.weight = Float(xml_node['weight'])
    recommendation.is_reverse = (xml_node['reverse'] == "true")
    recommendation
  end


  def generate_xml(top_node)
    node_recommendation = super(top_node)
    node_recommendation['weight'] = weight.to_s
    node_recommendation['reverse'] = "true" if is_reverse
    node_recommendation
  end

  # generate the weights for the considered products
  # return a hash idurl product_idurl -> weight
  def generate_hash_pidurl_weight(products) raise "should not be call" end

end

# generate_hash_pidurl_weight according to a predicate
class RecommendationPredicate < Recommendation

    key :predicate , String

    def self.initialize_from_xml(xml_node)
      recommendation_predicate = super(xml_node)
      recommendation_predicate.predicate = xml_node['predicate']
      recommendation_predicate
    end

    def generate_xml(top_node)
      node_recommendation_predicate = super(top_node)
      node_recommendation_predicate['predicate'] = predicate
      node_recommendation_predicate
    end

    def generate_hash_pidurl_weight(products)
      # interpreting predicate
      # prefix $ means feature idurl
      # prefix @ means a value for a feature
      #begin
        tokens = predicate.strip.split(' ')
        if tokens[1] == "has_value"
          feature_idurl = tokens.shift
          tokens.shift # skip has_value

          feature = knowledge.get_feature_by_idurl(feature_idurl)
          raise "wrong feature #{feature_idurl} in predicate #{predicate}" unless feature
          raise "feature #{feature_idurl} should be a FeatureTags in predicate #{predicate}" unless feature.is_a?(FeatureTags)
          # check tag idurls
          raise "you need at least one tag in predicate #{predicate}" unless tokens.size > 0
          authorized_tag_idurls = feature.tags.collect(&:idurl)
          tokens.each do |tag_idurl|
            raise "tag #{tag_idurl} doesn't exist for feature #{feature.idurl} in predicate #{predicate}" unless authorized_tag_idurls.include?(tag_idurl)
          end

          products.inject({}) do |h, product|
            if values = feature.get_value(product)
              # true if product hast at least one of the tokens values
              puts "h=#{h.inspect} product.idurl=#{product.idurl}"
              if tokens.any? { | tag_idurl | values.include?(tag_idurl) }
                h[product.idurl] = weight
              else
                h[product.idurl] = -1.0 * weight
              end
            end
            h
          end
        elsif tokens[1] == "my_other_predicate"
          # write an other predicate here
          # always return a hash product_idurl => weight
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


# generate_hash_pidurl_weight for a given product (or list of products)
class RecommendationProduct < Recommendation

  key :product_idurls, String

  def self.initialize_from_xml(xml_node)
    recommendation_product = super(xml_node)
    raise "eror no produt idurl for recommendation" unless xml_node['product_idurl']
    recommendation_product.product_idurls = xml_node['product_idurl'].split(' ')
    recommendation_product
  end

  def generate_xml(top_node)
    node_recommendation_product = super(top_node)
    node_recommendation_product['product_idurl'] = product_idurls
    node_recommendation_product
  end

  def generate_hash_pidurl_weight(products)
    products_scope = products.select { |p| product_idurls.include?(p.idurl) }
    products.inject({}) do |h, product|
      if product_idurls.include?(product.idurl)
        h[product.idurl] = weight
      elsif is_reverse
        h[product.idurl] = -weight
      end
      h
    end
  end

  def to_s() "@#{product_idurls}=#{weight}" end

end

# generate_hash_pidurl_weight based on a feature
# select product according to +/- important for a given feature
class RecommendationFeature < Recommendation
  key :feature_idurl, String

  def self.initialize_from_xml(xml_node)
    recommendation_feature = super(xml_node)
    recommendation_feature.feature_idurl = xml_node['feature_idurl']
    recommendation_feature
  end

  def generate_xml(top_node)
    node_recommendation_fpreference = super(top_node)
    node_recommendation_fpreference['feature_idurl'] = feature_idurl
    node_recommendation_fpreference
  end

  def generate_hash_pidurl_weight(products)
    feature = Knowledge.get_model.get_feature_by_idurl(feature_idurl)
    products.inject({}) { |h, product| h[product.idurl] = feature.aggregated_rating(product) * weight; h }
  end

  def to_s() "pref on feature #{feature_idurl}" end

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
      choice.generate_hash_pidurl_weight.each {|p,w| h[p] ||= 0; h[p] += w } ; h
    end
    PK_LOGGER.info "proba_ok=#{Root.as_percentage(proba_ok)} [#{choices.collect(&:idurl).join(', ')}] #{summed_weights.inspect}" if debug
    summed_weights.each { |p, w| (cumul[p] ||= []) << Distribution.new(w, proba_ok) }
    cumul
  end

  def self.weighted_average(distributions)
    distributions.inject(0.0)  { |v, d| v += (d.proba_ok * d.weight) }
  end

end
