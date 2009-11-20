require 'mongo_mapper'
require 'digest/md5'

class User < Root

  include MongoMapper::Document

  key :idurl, String # the md5 of the email
  key :rpx_identifier, String
  key :rpx_name, String
  key :rpx_username, String
  key :rpx_email, String
  key :role, String, :default => "unauthorised"
  key :category, String, :default => "citizen"
  key :reputation,  :default => 1.0
  key :wannabe_beta_tester, Boolean, :default => false

  many :reviews  # external, list of reviews
  many :quizze_instances # embedded documents

  timestamps!

  def self.is_main_document() true end

  def is_authorized() !is_unauthorized end
  def is_admin() role == "admin" end
  def is_tester() role == "tester" end
  def is_unauthorized() role == "unauthorised" end

  def nb_quizze_instances() quizze_instances.size end
  def nb_reviews() reviews.size end

  def self.initialize_from_xml(xml_node)
    user = super(xml_node)
    user.rpx_identifier = xml_node['rpx_identifier']
    user.rpx_name = xml_node['rpx_name']
    user.rpx_username = xml_node['rpx_username']
    user.rpx_email = xml_node['rpx_email']
    user.idurl = Digest::MD5.hexdigest(user.rpx_identifier)
    user.role = xml_node['role']
    user.category = xml_node['category']
    user.reputation = Float(xml_node['reputation'])
    xml_node.find("quizze_instances/QuizzeInstance").each do |node_quizze_instance|
      user.quizze_instances << QuizInstance.initialize.from_xml(node_quizze_instance)
    end
    user.save
    user.link_back
    user
  end

  def link_back(parent_object) 
    quizze_instances.each { |quizze_instance| quizze_instance.link_back(self) }
  end

  def generate_xml(top_node)
    node_user = super(top_node)
    node_user['rpx_identifier'] = rpx_identifier
    node_user['rpx_name'] = rpx_name
    node_user['rpx_username'] = rpx_username
    node_user['rpx_email'] =  rpx_email
    node_user['role'] = role
    node_user['category'] = category
    node_user['reputation'] = reputation.to_s
    node_user << (node_quizze_instances = XML::Node.new('quizze_instances'))
    quizze_instances.each { |quizze_instance| quizze_instance.generate_xml(node_quizze_instances) }
    node_user
  end

  #API public, return a quizze_instance (create a new one for a given quizze)
  def get_quizze_instance(quizze) QuizzeInstance.get_or_create_latest_for_quiz(quizze, self) end

  # step #1 user.record_answer
  # step #2 quizze_instance.record_answer
  # step #2 question.record_answer
  # step #2.1 choice.record_answer
  # step #3 trigger valide recommendations
  # recording an answer to a question from a user
  # dispatch the record_answer methods
  def record_answer(knowledge, quizze, question, choices_idurls_selected_ok)
    choices_idurls_selected_ok ||= []
    quizze_instance = get_quizze_instance(quizze)
    choices_ok = question.get_choice_ok_from_idurls(choices_idurls_selected_ok)
    knowledge.trigger_recommendations(quizze_instance, question, quizze.products, choices_ok, false)
    question.record_answer(self, choices_ok, false)
  end

  def cancel_answer(knowledge, quizze, question)
    quizze_instance = get_quizze_instance(quizze)
    last_answer = quizze_instance.user_last_answer(question.idurl)
    raise "no answer to cancel " unless last_answer
    knowledge.cancel_recommendations(question, last_answer, quizze_instance, quizze.products)
    quizze_instance.cancel_answer(last_answer)
    question.record_answer(self, last_answer.choices_ok(question), true)
  end

  # return the next question to be asked
  # return nil if there is no question available
  def get_next_question(knowledge, quizze)
    quizze_instance = get_quizze_instance(quizze)
    product_idurls_ranked_123 = quizze_instance.affinities.inject([]) do |l,a|
      l << a.product_idurl if a.ranking <= 3
      l
    end



    candidate_questions = get_candidate_questions(knowledge, quizze_instance)

    if candidate_questions.size > 0
      # get the question with the best separaration factor
      # for products with ranking 1 to 3
      Question.sort_by_discrimination(candidate_questions, product_idurls_ranked_123, self).first
    else
      # the user has answered all questions
      nil
    end
  end

  # return the questions that can be ask to this user
  # i.e. the unanswered question and precondition ok
  def get_candidate_questions(knowledge, quizze_instance)
    # TODO include the pre-condition
    knowledge.questions.find_all { |question| !quizze_instance.user_last_answer(question.idurl) }
  end

  def add_review(knowledge_idurl, feature_idurl, product_idurl, value)
    new_review = Review.new
    new_review.knowledge_idurl = knowledge_idurl
    new_review.feature_idurl = feature_idurl
    new_review.product_idurl = product_idurl
    new_review.value = value
    reviews <<  new_review
  end

  # return the sign-in provider of this user
  def registering_source
    if rpx_identifier.include?("google")
      "Google"
    elsif rpx_identifier.include?("facebook")
      "FaceBook"
    elsif rpx_identifier.include?("twitter")
      "Twitter"
    elsif rpx_identifier.include?("yahoo")
      "Yahoo"
    elsif rpx_identifier.include?("aol")
      "Aol"
    else
      "Unknown"
    end
  end
  
end


# handles the dialog with the user
# this is the interactive stuff
# this is the origin of any kind of record method
class QuizzeInstance < Root

  include MongoMapper::EmbeddedDocument
  
  key :quizze_idurl, String
  key :products_idurls_filtered, Array

  many :answers
  many :affinities

  attr_accessor :user, :hash_answered_question_answers, :hash_productidurl_affinity

  def link_back(user)
    self.user = user
    self.hash_answered_question_answers  = answers.inject({}) do |h, answer|
      answer.link_back(self)
      (h[answer.question_idurl] ||= []) << answer
      h
    end
    self.hash_productidurl_affinity  = affinities.inject({}) do |h, affinity|
      affinity.link_back(self)
      h[affinity.product_idurl] = affinity
      h
    end
  end

  def self.initialize_from_xml(xml_node)
    quizze_instance = super(xml_node)
    quizze_instance.quizze_idurl = xml_node['quizze_idurl']
    xml_node.find("affinities/Affinity").each do |node_affinity|
      quizze_instance.affinities << Affinity.initialize.from_xml(node_affinity)
    end
    quizze_instance.products_idurls_filtered = xml_node['products_idurls_filtered'].split(',').collect(&:trim)
    xml_node.find("answered/Answer").each do |node_answer|
      quizze_instance.answers << Answer.initialize_from_xml(node_answer)
    end
    quizze_instance
  end

  def generate_xml(top_node)
    node_quizze_instance = super(top_node)
    node_quizze_instance['quizze_idurl'] = quizze_idurl

    node_quizze_instance << (node_affinities = XML::Node.new('affinities'))
    hash_productidurl_affinity.each { |product_idurl, affinity| affinity.generate_xml(node_affinities) }

    node_quizze_instance['products_idurls_filtered'] = products_idurls_filtered.join(',')

    node_quizze_instance << (node_answered = XML::Node.new('answered'))
    puts "answers=#{answers.inspect}"
    answers.each do  |answer| answer.generate_xml(node_answered) end

    node_quizze_instance
  end

  # sort the affinities by ranking, and normalized the affinities measures (from 0 to 100)
  def sorted_affinities
    unless @sorted_affinities
      @sorted_affinities = hash_productidurl_affinity.collect { |product_idurl, affinity| affinity }
      @sorted_affinities.sort! { |a1, a2| a2.measure <=> a1.measure }
      # normalization...
      measure_max, measure_min = @sorted_affinities.first.measure, @sorted_affinities.last.measure
      if should_normalized = (measure_min != measure_max)
        a = 100.0 / (measure_max - measure_min); b = -a * measure_min
      end
      current_ranking = 0; previous_measure = nil
      @sorted_affinities.each do |affinity|
        affinity.normalized(should_normalized, a, b)
        if affinity.measure != previous_measure
          current_ranking += 1
          previous_measure = affinity.measure
        end
        affinity.ranking = current_ranking
      end
    end
    @sorted_affinities
  end

  # look up for the last quizze instance for a given quizze
  # if it doesn't exist create one...'
  def self.get_or_create_latest_for_quiz(quizze, user)
    quizze_instances = user.quizze_instances.find_all { |qi| qi.quizze_idurl == quizze.idurl }
    quizze_instance = quizze_instances.last # latest one... if any
    unless quizze_instance
      quizze_instance = QuizzeInstance.new(
        :quizze_idurl => quizze.idurl,
        :affinities => quizze.product_idurls.collect { |product_idurl| Affinity.create_product_idurl(product_idurl)} )
      user.quizze_instances << quizze_instance
      user.save
      quizze_instance.link_back(user)      
    end
    quizze_instance
  end

  def nb_answers()
    hash_answered_question_answers.inject(0) { |sum, (question_idurl, answers)| sum += answers.size }
  end

  # record a user's answer  for this quizze_instance
  def record_answer(knowledge_idurl, question_idurl, choice_idurls_ok)
    answer = Answer.new(:knowledge_idurl => knowledge_idurl,
                        :question_idurl => question_idurl,
                        :choice_idurls_ok => choice_idurls_ok,
                        :time_stamp => Time.now)
    (hash_answered_question_answers[question_idurl] ||= []) << answer
    answers << answer
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
      a.choice_idurls_ok
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


end


# describe an affinity measure of a user toward a product during a quizze instance
# between (-1.00 hated product and +1.00:prefered product)
# 0.0 means the product has not been classified yet
class Affinity < Root

  include MongoMapper::EmbeddedDocument

  key :product_idurl, String
  key :nb_weight, Float, :default => 0.0
  key :sum_weight, Float, :default => 0.0
  key :ranking, Integer, :default => 1

  attr_accessor :quiz_instance
  attr_accessor :measure_normalized # return the normalized value, between 0 and 100

  def link_back(quiz_instance) self.quiz_instance = quiz_instance end

  def add(weight, question_weight)
    self.nb_weight += question_weight
    self.sum_weight += question_weight * weight
  end
  
  def self.initialize_from_xml(xml_node)
    affinity = super(xml_node)
    affinity.product_idurl = xml_node['product_idurl']
    affinity.nb_weight = Float(xml_node['nb_weight'])
    affinity.sum_weight = Float(xml_node['sum_weight'])
    affinity.ranking = Integer(xml_node['ranking'] || 0)
    affinity
  end

  def self.create_product_idurl(product_idurl)
    new_affinity = Affinity.new
    new_affinity.product_idurl = product_idurl
    new_affinity
  end

  def generate_xml(top_node)
    node_affinity = super(top_node)
    node_affinity['product_idurl'] = product_idurl
    node_affinity['nb_weight'] = nb_weight.to_s
    node_affinity['sum_weight'] = sum_weight.to_s
    node_affinity['ranking'] = ranking.to_s if ranking
    node_affinity
  end


  # between (-1.00 hated product and +1.00:prefered product)
  def measure() @measure ||= (nb_weight == 0.0 ? 0.0 : sum_weight / nb_weight) end

  def normalized(should_normalized, a, b)
    @measure_normalized = (should_normalized ? (a * measure + b).round : 0)
  end

  NB_INPUT_4_MAX_CONFIDENCE = 5.0
  def confidence() @confidence ||= ([NB_INPUT_4_MAX_CONFIDENCE, nb_weight].min / NB_INPUT_4_MAX_CONFIDENCE) end

end



# describe an answer to a Question by a User during a Quizze Instance
# has answer ok assiociated
class Answer < Root

  include MongoMapper::EmbeddedDocument

  key :knowledge_idurl, String
  key :question_idurl, String # question
  key :choice_idurls_ok, Array
  key :time_stamp, Date

  attr_accessor :quiz_instance

  def link_back(quiz_instance) self.quiz_instance = quiz_instance end

  def self.initialize_from_xml(xml_node)
    answer = super(xml_node)
    answer.knowledge_idurl = xml_node["knowledge_idurl"]
    answer.question_idurl = xml_node["question_idurl"]
    answer.choice_idurls_ok = xml_node["choice_idurls_ok"].split(',')
    answer.time_stamp = Time.parse(xml_node["time_stamp"])
    answer
  end

  def generate_xml(top_node)
    node_answer = super(top_node)
    node_answer['knowledge_idurl'] = knowledge_idurl
    node_answer['question_idurl'] = question_idurl
    node_answer['choice_idurls_ok'] = choice_idurls_ok.join(',')
    node_answer['time_stamp'] = time_stamp.strftime(Root.default_date_format)
    node_answer
  end

  def has_opinion?() answers_ok.size > 0 end
  
  # return a list of choice object matching the answer of this user to the question
  def choices_ok(question) question.get_choice_ok_from_idurls(choice_idurls_ok) end

end






