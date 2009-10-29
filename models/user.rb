require 'mongo_mapper'


class User < Root

  include MongoMapper::Document

  key :rpx_identifier, String
  key :rpx_name, String
  key :rpx_username, String
  key :rpx_email, String
  key :promotion_code, String, :default => "none"
  key :status, String, :default => "citizen"
  key :reputation,  :default => 1

  #many :authored_opinions, Array
  #many :quiz_instances, Array

  key :updated_at, Time

  def is_authorized?() promotion_code == "auth" end

  def nb_quiz_instances() 0 end
  def nb_authored_opinions() 0 end

  #API public, return a quiz_instance (create a new one for a given quiz)
  def get_quiz_instance(quiz) Quizinstance.get_or_create_latest_for_quiz(quiz, self) end

  # step #1 user.record_answer
  # step #2 quiz_instance.record_answer
  # step #2 question.record_answer
  # step #2.1 choice.record_answer
  # step #3 trigger valide recommendations
  # recording an answer to a question from a user
  # dispatch the record_answer methods
  def record_answer(knowledge, quiz, question, choices_idurls_selected_ok, timestamp=Time.now)
    choices_idurls_selected_ok ||= []
    quiz_instance = get_quiz_instance(quiz)
    choices_ok = question.get_choice_ok_from_idurls(choices_idurls_selected_ok)
    knowledge.trigger_recommendations(quiz_instance, question, quiz.products, choices_ok, false)
    question.record_answer(self, choices_ok, false)
  end


  def cancel_answer(knowledge, quiz, question, timestamp=Time.now)
    quiz_instance = get_quiz_instance(quiz)
    last_answer = quiz_instance.user_last_answer(question.idurl)
    raise "no answer to cancel " unless last_answer
    knowledge.cancel_recommendations(question, last_answer, quiz_instance, quiz.products)
    quiz_instance.cancel_answer(last_answer)
    question.record_answer(self, last_answer.choices_ok(question), true)
  end


  # return the next question to be asked
  # return nil if there is no question available
  def get_next_question(knowledge, quiz)
    quiz_instance = get_quiz_instance(quiz)
    candidate_questions = get_candidate_questions(knowledge, quiz_instance)
    quiz_products = quiz.products
    if candidate_questions.size > 0
      # get the question with the best separaration factor
      # take the 2 closest products...
      candidate_questions.first
    else
      # the user has answered all questions
      nil
    end
  end

  # return the questions that can be ask to this user
  # i.e. the unanswered question and precondition ok
  def get_candidate_questions(knowledge, quiz_instance)
    # TO DO include the pre-condition
    knowledge.questions.find_all { |question| !quiz_instance.user_last_answer(question.idurl) }
  end

  def add_opinion(knowledge_idurl, feature_idurl, product_idurl, value)
    new_opinion = Opinion.new
    new_opinion.knowledge_idurl = knowledge_idurl
    new_opinion.feature_idurl = feature_idurl
    new_opinion.product_idurl = product_idurl
    new_opinion.value = value
    authored_opinions <<  new_opinion
  end

end


# handles the dialog with the user
# this is the interactive stuff
# this is the origin of any kind of record method
class Quizinstance < Root

  attr_accessor :quiz_idurl, :hash_productidurl_affinity, :hash_answered_question_answers, :nb_products_to_discriminate, :products_idurls_filtered


  def initialize_from_xml(xml_node)
    super(xml_node)
    self.quiz_idurl = xml_node['quiz_idurl']
    self.hash_productidurl_affinity = Root.get_hash_from_xml(xml_node, 'affinities/affinity', 'product_idurl') { |node_affinity| Affinity.create_from_xml(node_affinity) }
    self.products_idurls_filtered = Root.get_collection_from_xml(xml_node, 'products_filtered/product') { |node_product_filtered| node_product_filtered['idurl'] }
    self.hash_answered_question_answers = {}
    Root.get_collection_from_xml(xml_node, 'answered/answer') do |node_answer|
      answer = Answer.create_from_xml(node_answer)
      (self.hash_answered_question_answers[answer.question_idurl] ||= []) << answer
    end
    self.nb_products_to_discriminate = 2 # TODO this is an important parameter
  end

  # return a list of product that we need to differentiate
  # at the beginning all products of the quiz
  # and this should end to a short list, 2 or 3 products
  def products
    hash_productidurl_affinity.collect {  |product_idurl, affinity| Product.get_from_cache(product_idurl) }
  end


  def sorted_affinities
    unless @sorted_affinities
      @sorted_affinities = hash_productidurl_affinity.collect { |product_idurl, affinity| affinity }
      @sorted_affinities.sort! { |a1, a2| a2.measure <=> a1.measure }
      current_ranking = 0; previous_measure = nil
      @sorted_affinities.each do |a|
        if a.measure != previous_measure
          current_ranking += 1
          previous_measure = a.measure
        end
        a.ranking = current_ranking
      end
    end
    @sorted_affinities
  end

  def generate_xml(top_node)
    node_quiz_instance = super(top_node)
    node_quiz_instance['quiz_idurl'] = quiz_idurl

    node_quiz_instance << (node_affinities = XML::Node.new('affinities'))
    hash_productidurl_affinity.each { |product_idurl, affinity| affinity.generate_xml(node_affinities) } if hash_productidurl_affinity

    node_quiz_instance << (node_products_filtered = XML::Node.new('products_filtered'))
    (products_idurls_filtered || []).each do |product_idurl_filtered|
      node_products_filtered << (node_product_triggered = XML::Node.new('product'))
      node_product_triggered['idurl'] = product_idurl_filtered
    end



    node_quiz_instance << (node_answered = XML::Node.new('answered'))
    hash_answered_question_answers.each do  |question_idurl, answers|
      answers.each { |answer| answer.generate_xml(node_answered) }
    end

    node_quiz_instance
  end

  # look up for the last quiz instance for a given quiz
  # if it doesn't exist create one...'
  def self.get_or_create_latest_for_quiz(quiz, pkz_user)
    quiz_instances = pkz_user.quiz_instances.find_all { |qi| qi.quiz_idurl == quiz.idurl }
    quiz_instance = quiz_instances.last # latest one... if any
    unless quiz_instance
      pkz_user.quiz_instances << (quiz_instance = self.new)
      quiz_instance.idurl = "#{quiz.idurl}_1"
      quiz_instance.quiz_idurl = quiz.idurl
      quiz_instance.hash_productidurl_affinity = quiz.product_idurls.inject({}) { |h, product_idurl| h[product_idurl] = Affinity.create_with_parameters(product_idurl); h }
      quiz_instance.hash_answered_question_answers = {}
      quiz_instance.nb_products_to_discriminate = 2
      pkz_user.save
    end
    quiz_instance
  end

  def nb_answers
    hash_answered_question_answers.inject(0) { |sum, (question_idurl, answers)| sum += answers.size }
  end

  # record a user's answer  for this quizinstance
  def record_answer(knowledge_idurl, question_idurl, choice_idurls_ok)
    (hash_answered_question_answers[question_idurl] ||= []) << (answer = Answer.create_with_parameters(knowledge_idurl, question_idurl, choice_idurls_ok))
    answer
  end

  def cancel_answer(last_answer)
    raise "no answer to cancel !" unless last_answer
    answers.delete(last_answer)
    last_answer
  end

  # return the last answer of a user to a given question
  # return nil if no answer
  # if choice_idurl , return the answer binary of the last answer
  # type_return == (:last or :list) either the last of the list of answers
  def user_last_answer(question_idurl, type_return = :last)
    if (answers = hash_answered_question_answers[question_idurl]) and answers.size > 0
      type_return == :last ? answers.last : answers
    end
  end

  def user_last_answer_choice_idurls_ok(question_idurl)
    if (a = user_last_answer(question_idurl))
      a.answers_ok.collect {|aok| aok.choice_idurl }
    else
      nil
    end
  end

  # return true or false if the user has answered "value_answered" ("ok", "ko") to question_idurl and choice_idurl
  # return false if the user has not answred
  def user_answered?(question_idurl, choice_idurl, value_answered)
    raise "wrong answered value=#{value_answered}" unless ["ok", "ko"].include?(value_answered)
    recorded_answer = user_last_answer(question_idurl, :last)
    recorded_answer.get_answer_code_for(choice_idurl) == value_answered  if recorded_answer
  end




  private


end


# describe an affinity measure of a user toward a product during a quiz instance
# between (-1.00 hated product and +1.00:prefered product)
# 0.0 means the product has not been classified yet
class Affinity < Root

  attr_accessor :product_idurl, :nb_weight, :sum_weight, :ranking

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.product_idurl = xml_node['product_idurl']
    self.nb_weight = Float(xml_node['nb_weight'])
    self.sum_weight = Float(xml_node['sum_weight'])
    self.ranking = Integer(xml_node['ranking'] || 0)
  end

  def generate_xml(top_node)
    node_affinity = super(top_node)
    node_affinity['product_idurl'] = product_idurl
    node_affinity['nb_weight'] = nb_weight.to_s
    node_affinity['sum_weight'] = sum_weight.to_s
    node_affinity['ranking'] = ranking.to_s if ranking
    node_affinity
  end

  def self.create_with_parameters(product_idurl)
    affinity = super(nil)
    affinity.product_idurl = product_idurl
    affinity.nb_weight = 0.0
    affinity.sum_weight = 0.0
    affinity
  end

  # between (-1.00 hated product and +1.00:prefered product)
  def measure() (nb_weight == 0.0 ? 0.0 : sum_weight / nb_weight) end


  NB_INPUT_4_MAX_CONFIDENCE = 5.0
  def confidence() [NB_INPUT_4_MAX_CONFIDENCE, nb_weight].min / NB_INPUT_4_MAX_CONFIDENCE end

end

# describe an answer to a Question by a User during a Quiz Instance
# has answer ok assiociated
class Answer < Root

  attr_accessor :knowledge_idurl, :question_idurl, :timestamp, :answers_ok

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledge_idurl = xml_node['knowledge_idurl']
    self.question_idurl = xml_node['question_idurl']
    self.timestamp =  Time.parse(xml_node['timestamp'])
    self.answers_ok = Root.get_collection_from_xml(xml_node, 'answerok') { |node_answerok| Answerok.create_from_xml(node_answerok) }
  end

  def has_opinion?() answers_ok.size > 0 end

  def generate_xml(top_node)
    node_answer = super(top_node)
    node_answer['knowledge_idurl'] = knowledge_idurl
    node_answer['question_idurl'] = question_idurl
    node_answer['timestamp'] = timestamp.strftime(Root.default_date_format)
    answers_ok.each { |answer_binary| answer_binary.generate_xml(node_answer)}
    node_answer
  end

  # create a new answer object (with subobjects)
  def self.create_with_parameters(knowledge_idurl, question_idurl, choice_idurls_ok)
    answer = Answer.new
    answer.knowledge_idurl = knowledge_idurl
    answer.question_idurl = question_idurl
    answer.timestamp = Time.now
    answer.answers_ok = choice_idurls_ok.collect {|choice_idurl_ok| Answerok.create_with_parameters(choice_idurl_ok) }
    answer
  end

  def choice_idurls_ok() answers_ok.collect(&:choice_idurl) end

  # return a list of choice object matching the answer of this user to the question
  def choices_ok(question) question.get_choice_ok_from_idurls(choice_idurls_ok) end

end

# describe an OK answer to a Question's choice by a User during a Quiz Instance
class Answerok < Root

  attr_accessor :choice_idurl

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.choice_idurl = xml_node['choice_idurl']
  end

  def generate_xml(top_node)
    node_answer_binary = super(top_node)
    node_answer_binary['choice_idurl'] = choice_idurl
    node_answer_binary
  end

  def self.create_with_parameters(choice_idurl)
    answer_binary = super(nil)
    answer_binary.choice_idurl = choice_idurl
    answer_binary
  end

end

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Opinion < Root

  attr_accessor :knowledge_idurl, :feature_idurl, :product_idurl, :timestamp, :db_id, :min_rating, :max_rating, :value, :hash_idurl_background


  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledge_idurl = xml_node['knowledge_idurl']
    self.feature_idurl = xml_node['feature_idurl']
    self.product_idurl = xml_node['product_idurl']
    self.min_rating = xml_node['min_rating']
    self.max_rating = xml_node['max_rating']
    self.db_id = xml_node['db_id']
    self.timestamp =  Time.parse(xml_node['timestamp']) if xml_node['timestamp']
    self.value = Float(xml_node['value'])
    self.hash_idurl_background = Root.get_hash_from_xml(xml_node, 'background', 'idurl') { |node_background| Background.create_from_xml(node_background) }
  end

  def generate_xml(top_node)
    node_opinion = super(top_node)
    node_opinion['value'] = value.to_s
    hash_idurl_background.each { |idurl, background| background.generate_xml(node_opinion) }  if hash_idurl_background
    node_opinion['db_id'] = db_id.to_s if db_id
    node_opinion['knowledge_idurl'] = knowledge_idurl
    node_opinion['feature_idurl'] = feature_idurl
    node_opinion['min_rating'] = min_rating
    node_opinion['max_rating'] = max_rating
    node_opinion['product_idurl'] = product_idurl
    node_opinion['timestamp'] = timestamp.strftime(Root.default_date_format) if timestamp
    node_opinion
  end



end