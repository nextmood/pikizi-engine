require 'pkz_xml.rb'

module Pikizi

require 'xml'
  
class User < Root

  attr_accessor :key, :reputation, :category, :quiz_instances , :authored_opinions

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.reputation =  Float(xml_node['reputation'] || 1.0)
    self.category =  xml_node['category'] || "citizen"
    self.quiz_instances = Root.get_collection_from_xml(xml_node, 'quiz_instances/quizinstance') { |node_quizinstance| Quizinstance.create_from_xml(node_quizinstance) }
    self.authored_opinions = Root.get_collection_from_xml(xml_node, 'authored/opinion') { |node_authored_opinion| Opinion.create_from_xml(node_authored_opinion) }
  end


  def generate_xml(top_node)
    node_user = super(top_node)
    node_user['reputation'] = (reputation || 1.0).to_s
    node_user['category'] = category || "citizen"

    node_user << (node_quiz_instances = XML::Node.new('quiz_instances'))  
    quiz_instances.each { |qi| qi.generate_xml(node_quiz_instances) } if quiz_instances
    node_user << (node_authored = XML::Node.new('authored'))  
    authored_opinions.each { |authored_opinion| authored_opinion.generate_xml(node_authored) }
    node_user
  end

  def self.get_from_cache(user_key, reload=nil)
    Rails.cache.fetch("U#{user_key}", :force => reload) { User.create_from_xml(user_key) }
  end

  # load an xml file... and retutn a User object
  def self.create_from_xml(user_key)
    raise "error user_key=#{user_key.inspect}" unless user_key
    unless key_exist?(user_key)
      pkz_user = Pikizi::User.new
      pkz_user.key = user_key
      pkz_user.label = "Label for #{user_key}"
      pkz_user.authored_opinions = []
      pkz_user.quiz_instances = []
      pkz_user.reputation = 1.0
      pkz_user.save # save in a file
      PK_LOGGER.info "creating XML user #{user_key}"
    end
    PK_LOGGER.info "loading XML user #{user_key} from filesystem"
    super(XML::Document.file(filename_data(user_key)).root)
  end

  def nb_quiz_instances() quiz_instances.size end
  def nb_authored_opinions() authored_opinions.size end

  #API public, return a quiz_instance (create a new one for a given quiz)
  def get_quiz_instance(quiz) Quizinstance.get_or_create_latest_for_quiz(quiz, self) end

  # step #1 user.record_answer
  # step #2 quiz_instance.record_answer
  # step #2 question.record_answer
  # step #2.1 choice.record_answer
  # step #3 trigger valide tips
  # recording an answer to a question from a user
  # dispatch the record_answer methods
  def record_answer(knowledge, quiz, question, choices_keys_selected_ok, timestamp=Time.now)
    choices_keys_selected_ok ||= []
    quiz_instance = get_quiz_instance(quiz)
    choices_ok = question.get_choice_ok_from_keys(choices_keys_selected_ok)
    knowledge.trigger_tips(quiz_instance, question, quiz.products, choices_ok, false)
    question.record_answer(self, choices_ok, false)
  end


  def cancel_answer(knowledge, quiz, question, timestamp=Time.now)
    quiz_instance = get_quiz_instance(quiz)
    last_answer = quiz_instance.user_last_answer(question.key)
    raise "no answer to cancel " unless last_answer    
    knowledge.cancel_recommendations(last_answer, quiz_instance, quiz.products)
    quiz_instance.cancel_answer(last_answer)
    question.record_answer(self, last_answer.choices_ok(question), true)
  end


  # return the next question to be asked
  # return nil if there is no question available
  def get_next_question(knowledge, quiz)
    quiz_instance = get_quiz_instance(quiz)
    unanswered_questions = knowledge.questions.find_all { |question| !quiz_instance.user_last_answer(question.key) }
    quiz_products = quiz.products
    if unanswered_questions.size > 0
      # get the question with the best separartion factor
      unanswered_questions.max { |q1, q2| q1.separation(quiz_products, self) <=> q2.separation(quiz_products, self) }
    else
      # the user has answered all questions
      nil
    end    
  end

  def add_opinion(knowledge_key, feature_key, product_key, value)
    new_opinion = Opinion.new
    new_opinion.knowledge_key = knowledge_key
    new_opinion.feature_key = feature_key
    new_opinion.product_key = product_key
    new_opinion.value = value
    authored_opinions <<  new_opinion
  end



  private





end

# handles the dialog with the user
# this is the interactive stuff
# this is the origin of any kind of record method 
class Quizinstance < Root

  attr_accessor :quiz_key, :hash_productkey_affinity, :hash_answered_question_answers, :nb_products_to_discriminate, :products_keys_filtered
  

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.quiz_key = xml_node['quiz_key']
    self.hash_productkey_affinity = Root.get_hash_from_xml(xml_node, 'affinities/affinity', 'product_key') { |node_affinity| Affinity.create_from_xml(node_affinity) }
    self.products_keys_filtered = Root.get_collection_from_xml(xml_node, 'products_filtered/product') { |node_product_filtered| node_product_filtered['key'] }
    self.hash_answered_question_answers = {}
    Root.get_collection_from_xml(xml_node, 'answered/answer') do |node_answer|
      answer = Answer.create_from_xml(node_answer)
      (self.hash_answered_question_answers[answer.question_key] ||= []) << answer
    end
    self.nb_products_to_discriminate = 2 # TODO this is an important parameter
  end

  # return a list of product that we need to differentiate
  # at the beginning all products of the quiz
  # and this should end to a short list, 2 or 3 products
  def products
    hash_productkey_affinity.collect {  |product_key, affinity| Product.get_from_cache(product_key) }
  end


  def sorted_affinities
    unless @sorted_affinities
      @sorted_affinities = hash_productkey_affinity.collect { |product_key, affinity| affinity }
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
    node_quiz_instance['quiz_key'] = quiz_key

    node_quiz_instance << (node_affinities = XML::Node.new('affinities'))
    hash_productkey_affinity.each { |product_key, affinity| affinity.generate_xml(node_affinities) } if hash_productkey_affinity

    node_quiz_instance << (node_products_filtered = XML::Node.new('products_filtered'))
    (products_keys_filtered || []).each do |product_key_filtered|
      node_products_filtered << (node_product_triggered = XML::Node.new('product'))
      node_product_triggered['key'] = product_key_filtered
    end



    node_quiz_instance << (node_answered = XML::Node.new('answered'))
    hash_answered_question_answers.each do  |question_key, answers|
      answers.each { |answer| answer.generate_xml(node_answered) }        
    end
    
    node_quiz_instance
  end

  # look up for the last quiz instance for a given quiz
  # if it doesn't exist create one...'
  def self.get_or_create_latest_for_quiz(quiz, pkz_user)
    quiz_instances = pkz_user.quiz_instances.find_all { |qi| qi.quiz_key == quiz.key }
    quiz_instance = quiz_instances.last # latest one... if any
    unless quiz_instance
      pkz_user.quiz_instances << (quiz_instance = self.new)
      quiz_instance.key = "#{quiz.key}_1"
      quiz_instance.quiz_key = quiz.key
      quiz_instance.hash_productkey_affinity = quiz.product_keys.inject({}) { |h, product_key| h[product_key] = Affinity.create_with_parameters(product_key); h }
      quiz_instance.hash_answered_question_answers = {}
      quiz_instance.nb_products_to_discriminate = 2
      pkz_user.save
    end
    quiz_instance
  end

  def nb_answers
    hash_answered_question_answers.inject(0) { |sum, (question_key, answers)| sum += answers.size }
  end

  # record a user's answer  for this quizinstance
  def record_answer(question_key, choice_keys_ok)
    (hash_answered_question_answers[question_key] ||= []) << (answer = Answer.create_with_parameters(question_key, choice_keys_ok))
    answer
  end

  def cancel_answer(last_answer)
    raise "no answer to cancel !" unless last_answer    
    answers.delete(last_answer)
    last_answer
  end

  # return the last answer of a user to a given question
  # return nil if no answer
  # if choice_key , return the answer binary of the last answer
  # type_return == (:last or :list) either the last of the list of answers
  def user_last_answer(question_key, type_return = :last)
    if (answers = hash_answered_question_answers[question_key]) and answers.size > 0
      type_return == :last ? answers.last : answers
    end 
  end

  def user_last_answer_choice_keys_ok(question_key)
    if (a = user_last_answer(question_key))
      a.answers_ok.collect {|aok| aok.choice_key }
    else
      nil
    end 
  end

  # return true or false if the user has answered "value_answered" ("ok", "ko") to question_key and choice_key
  # return false if the user has not answred
  def user_answered?(question_key, choice_key, value_answered)
    raise "wrong answered value=#{value_answered}" unless ["ok", "ko"].include?(value_answered)
    recorded_answer = user_last_answer(question_key, :last)
    recorded_answer.get_answer_code_for(choice_key) == value_answered  if recorded_answer
  end




  private


end


# describe an affinity measure of a user toward a product during a quiz instance
# between (-1.00 hated product and +1.00:prefered product)
# 0.0 means the product has not been classified yet
class Affinity < Root

  attr_accessor :product_key, :nb_tensor, :sum_tensor, :ranking

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.product_key = xml_node['product_key']
    self.nb_tensor = Float(xml_node['nb_tensor'])
    self.sum_tensor = Float(xml_node['sum_tensor'])
    self.ranking = Integer(xml_node['ranking'] || 0)
  end

  def generate_xml(top_node)
    node_affinity = super(top_node)
    node_affinity['product_key'] = product_key
    node_affinity['nb_tensor'] = nb_tensor.to_s
    node_affinity['sum_tensor'] = sum_tensor.to_s
    node_affinity['ranking'] = ranking.to_s if ranking
    node_affinity
  end

  def self.create_with_parameters(product_key)
    affinity = super(nil)
    affinity.product_key = product_key
    affinity.nb_tensor = 0.0
    affinity.sum_tensor = 0.0
    affinity
  end

  # between (-1.00 hated product and +1.00:prefered product)
  def measure() (nb_tensor == 0.0 ? 0.0 : sum_tensor / nb_tensor) end

  # record a new tensor (a value between -1.00 and +1.00)
  # a tensor is generated by a recommendation (made of if/ then) (link to a choice made by a user)
  def add_tensor(tensor, reverse_mode)
    sign = reverse_mode ? -1 : +1
    self.nb_tensor += sign
    self.sum_tensor += tensor.weight * sign
  end

  # confidence is dedicated to weight the affinity tensor
  NB_INPUT_4_MAX_CONFIDENCE = 5.0
  def confidence() [NB_INPUT_4_MAX_CONFIDENCE, nb_tensor].min / NB_INPUT_4_MAX_CONFIDENCE end

end

# describe an answer to a Question by a User during a Quiz Instance
# has answer ok assiociated
class Answer < Root

  attr_accessor :question_key, :timestamp, :answers_ok

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.question_key = xml_node['question_key']
    self.timestamp =  Time.parse(xml_node['timestamp'])
    self.answers_ok = Root.get_collection_from_xml(xml_node, 'answerok') { |node_answerok| Answerok.create_from_xml(node_answerok) }
  end

  def has_opinion?() answers_ok.size > 0 end

  def generate_xml(top_node)
    node_answer = super(top_node)
    node_answer['question_key'] = question_key
    node_answer['timestamp'] = timestamp.strftime(Root.default_date_format)  
    answers_ok.each { |answer_binary| answer_binary.generate_xml(node_answer)}
    node_answer
  end

  # create a new answer object (with subobjects)
  def self.create_with_parameters(question_key, choice_keys_ok)
    answer = Answer.new
    answer.question_key = question_key
    answer.timestamp = Time.now
    answer.answers_ok = choice_keys_ok.collect {|choice_key_ok| Answerok.create_with_parameters(choice_key_ok) }
    answer
  end

  def choice_keys_ok() answers_ok.collect(&:choice_key) end

  # return a list of choice object matching the answer of this user to the question
  def choices_ok(question) question.get_choice_ok_from_keys(choice_keys_ok) end
  
end

# describe an OK answer to a Question's choice by a User during a Quiz Instance
class Answerok < Root

  attr_accessor :choice_key

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.choice_key = xml_node['choice_key']
  end

  def generate_xml(top_node)
    node_answer_binary = super(top_node)
    node_answer_binary['choice_key'] = choice_key
    node_answer_binary
  end

  def self.create_with_parameters(choice_key)
    answer_binary = super(nil)
    answer_binary.choice_key = choice_key
    answer_binary
  end

end

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0 
class Opinion < Root

  attr_accessor :knowledge_key, :feature_key, :product_key, :timestamp, :db_id, :min_rating, :max_rating, :value, :hash_key_background


  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledge_key = xml_node['knowledge_key']
    self.feature_key = xml_node['feature_key']
    self.product_key = xml_node['product_key']
    self.min_rating = xml_node['min_rating']
    self.max_rating = xml_node['max_rating']
    self.db_id = xml_node['db_id']
    self.timestamp =  Time.parse(xml_node['timestamp']) if xml_node['timestamp']
    self.value = Float(xml_node['value'])
    self.hash_key_background = Root.get_hash_from_xml(xml_node, 'background', 'key') { |node_background| Background.create_from_xml(node_background) }
  end

  def generate_xml(top_node)
    node_opinion = super(top_node)
    node_opinion['value'] = value.to_s
    hash_key_background.each { |key, background| background.generate_xml(node_opinion) }  if hash_key_background
    node_opinion['db_id'] = db_id.to_s if db_id
    node_opinion['knowledge_key'] = knowledge_key
    node_opinion['feature_key'] = feature_key
    node_opinion['min_rating'] = min_rating
    node_opinion['max_rating'] = max_rating
    node_opinion['product_key'] = product_key
    node_opinion['timestamp'] = timestamp.strftime(Root.default_date_format) if timestamp
    node_opinion
  end



end

  
end