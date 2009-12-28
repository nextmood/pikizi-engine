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
  key :category, String, :default => "user"
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

  # load a user object from an idurl  or a mongo db_id
  def link_back() quizze_instances.each { |quizze_instance| quizze_instance.link_back(self) } end

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
  def get_latest_quizze_instance() QuizzeInstance.get_latest_quizze(self) end
  def create_quizze_instance(quizze) QuizzeInstance.create_for_quizze(quizze, self) end

  # step #1 user.record_answer
  # step #2 quizze_instance.record_answer
  # step #2 question.record_answer
  # step #2.1 choice.record_answer
  # step #3 trigger valide recommendations
  # recording an answer to a question from a user
  # dispatch the record_answer methods
  def record_answer(knowledge, quizze, question, choices_idurls_selected_ok)
    choices_idurls_selected_ok ||= []
    quizze_instance = get_latest_quizze_instance
    raise "error" unless quizze_instance and quizze_instance.get_quizze == quizze
    choices_ok = question.get_choice_ok_from_idurls(choices_idurls_selected_ok)
    knowledge.trigger_recommendations(quizze_instance, question, quizze.products, choices_ok, false)
    question.record_answer(self, choices_ok, false)
  end

  def cancel_answer(knowledge, quizze, question)
    quizze_instance = get_latest_quizze_instance
    raise "error" unless quizze_instance and quizze_instance.quizze == quizze
    last_answer = quizze_instance.user_last_answer(question.idurl)
    raise "no answer to cancel " unless last_answer
    knowledge.cancel_recommendations(question, last_answer, quizze_instance, quizze.products)
    quizze_instance.cancel_answer(last_answer)
    question.record_answer(self, last_answer.choices_ok(question), true)
  end

  # return the next question to be asked
  # return nil if there is no question available
  def get_next_question(knowledge, quizze)
    quizze_instance = get_latest_quizze_instance
    raise "error" unless quizze_instance and quizze_instance.get_quizze == quizze
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
  key :created_at, Time  # when the QuizInstqnce was created
  key :closed_at, Time, :default => nil   # when the suer or system (time out) has closed this QuizzeInstance
  key :question_ids, Array

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

  def get_quizze() @quizze ||= Quizze.load(quizze_idurl) end
  
  def self.initialize_from_xml(xml_node)
    quizze_instance = super(xml_node)
    quizze_instance.quizze_idurl = xml_node['quizze_idurl']
    xml_node.find("affinities/Affinity").each do |node_affinity|
      quizze_instance.affinities << Affinity.initialize.from_xml(node_affinity)
    end

    quizze_instance.created_at = Time.parse(xml_node["created_at"])
    quizze_instance.closed_at = (xml_node["closed_at"] ? Time.parse(xml_node["closed_at"])  : nil)

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

    node_quizze_instance['created_at'] = created_at.strftime(Root.default_date_format)
    node_quizze_instance['closed_at'] = closed_at.strftime(Root.default_date_format) if closed_at

    node_quizze_instance << (node_answered = XML::Node.new('answered'))
    puts "answers=#{answers.inspect}"
    answers.each do  |answer| answer.generate_xml(node_answered) end

    node_quizze_instance
  end

  # sort the affinities by ranking
  def sorted_affinities
    unless @sorted_affinities
      @sorted_affinities = hash_productidurl_affinity.collect { |product_idurl, affinity| affinity }
      @sorted_affinities.sort! { |a1, a2| a2.measure <=> a1.measure }
      current_ranking = 0; previous_measure = nil
      @sorted_affinities.each do |affinity|
        if affinity.measure != previous_measure
          current_ranking += 1
          previous_measure = affinity.measure
        end
        affinity.ranking = current_ranking
      end
    end
    @sorted_affinities
  end


  def self.create_for_quizze(quizze, user)
    if existing_quizze_instance = QuizzeInstance.get_latest_quizze(user)
      existing_quizze_instance.closed_at = Time.now
      user.save  
    end
    quizze_instance = QuizzeInstance.new(
      :quizze_idurl => quizze.idurl,
      :created_at => Time.now,
      :affinities => quizze.product_idurls.collect { |product_idurl| Affinity.create_product_idurl(product_idurl)}, 
      :question_ids => quizze.questions.collect(&:id))
    user.quizze_instances << quizze_instance
    user.save
    quizze_instance.link_back(user)
    quizze_instance
  end

  # look up for the last quizze instance
  def self.get_latest_quizze(user)
    quizze_instances = user.quizze_instances.find_all { |qi| qi.closed_at.nil? }
    raise "we should not have more than one quiz instance open" if quizze_instances.size > 1
    quizze_instances.first
  end

  # return the last time this quizze instance was updated
  def last_update() (last_answer = answers.last) ? last_answer.time_stamp : created_at end

  def nb_answers() answers.size end
  #  hash_answered_question_answers.inject(0) { |sum, (question_idurl, answers)| sum += answers.size }

  def nb_products_ranked_at_most(max_ranking=3)
    34  
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

  # return a  explanations, hash_dimension2answers
  # explanations[product_idurl]["aggregated_dimensions"][:sum | :percentage]
  # explanations[product_idurl][question_idurl][:sum | :percentage]
  # hash_dimension2answers[dimension] => list of answers
  # hash_question_idurl2min_max_weight => min, max weight for a given question
  def get_explanations(knowledge, sorted_affinities)
    hash_dimension2answers = answers.group_by do |answer|
      answer.has_opinion? ? answer.question(knowledge).dimension : :no_opinion
    end

    explanations = {}
    hash_question_idurl2min_max_weight = {}
    answers.each do |answer|
      question = answer.question(knowledge)
      hash_pidurl2weight = HashProductIdurl2Weight.after_answer(question, answer)
      hash_pidurl2weight = hash_pidurl2weight * question.weight
      min_weight, max_weight = hash_pidurl2weight.min_max
      hash_question_idurl2min_max_weight[answer.question_idurl] = [min_weight, max_weight]
      ab = (min_weight == max_weight) ? nil : Root.rule3_ab(min_weight, max_weight)
      sorted_affinities.each do |affinity|
        product_idurl = affinity.product_idurl
        weight = hash_pidurl2weight[product_idurl]
        explanations[product_idurl] ||= {}
        explanations[product_idurl][answer.question_idurl] = { :sum => weight, :percentage => (ab ? Root.rule3_cache(weight, ab) : 1.0) }
      end
    end

    # compute the sum per dimension
    hash_dimension2answers.each do |dimension, answers_4_dimension|
      puts "answers_4_dimension=#{answers_4_dimension.class}"
      sum_weight_questions = answers_4_dimension.inject(0.0) { |s, answer| s += answer.question(knowledge).weight }
      explanations.each do |product_idurl, explanation|
        sum_weight = 0.0
        sum_percentage = 0.0
        sum_weight_questions = 0.0
        answers_4_dimension.each do |answer|
          question_weight = answer.question(knowledge).weight
          sum_weight += explanation[answer.question_idurl][:sum]
          sum_percentage += (explanation[answer.question_idurl][:percentage] * question_weight)
          sum_weight_questions += question_weight
        end
        explanation["dimension_#{dimension}"] = {:sum => sum_weight, :percentage => sum_percentage / sum_weight_questions }
      end
    end

    # compute the total sum
    sum_weight_questions = answers.inject(0.0) { |s, answer| s += answer.question(knowledge).weight }
    explanations.each do |product_idurl, explanation|
      sum_weight = answers.inject(0.0) { |s, answer| s += explanation[answer.question_idurl][:sum] }
      sum_percentage = answers.inject(0.0) { |s, answer| s += (explanation[answer.question_idurl][:percentage] * answer.question(knowledge).weight) }

      explanation["aggregated_dimensions"] = {:sum => sum_weight, :percentage => sum_percentage / sum_weight_questions }
    end

    [explanations, hash_dimension2answers, hash_question_idurl2min_max_weight]
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
  key :is_filtered_out, Boolean, :default => false
  key :feedback, Integer, :default => 0

  attr_accessor :quiz_instance

  def link_back(quiz_instance) self.quiz_instance = quiz_instance end

  def add(weight, question_weight)
    self.nb_weight += question_weight
    self.sum_weight += weight * question_weight
  end

  def product(knowledge) knowledge.get_product_by_idurl(product_idurl) end

  def self.initialize_from_xml(xml_node)
    affinity = super(xml_node)
    affinity.product_idurl = xml_node['product_idurl']
    affinity.nb_weight = Float(xml_node['nb_weight'])
    affinity.sum_weight = Float(xml_node['sum_weight'])
    affinity.ranking = Integer(xml_node['ranking'] || 0)
    affinity.is_filtered_out = (xml_node['is_filtered_out'] == "true")
    affinity.feedback = Integer(xml_node['feedback'] || 0)
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
    node_affinity['is_filtered_out'] = "true" if is_filtered_out
    node_affinity['feedback'] = feedback.to_s if feedback
    node_affinity
  end


  # between (-1.00 hated product and +1.00:prefered product)
  def measure() @measure ||= (nb_weight == 0.0 ? 0.0 : sum_weight / nb_weight) end


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
  key :time_stamp, Time

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

  def has_opinion?() choice_idurls_ok.size > 0 end

  # return a list of choice object matching the answer of this user to the question
  def choices_ok(question) question.get_choice_ok_from_idurls(choice_idurls_ok) end

  def question(knowledge) knowledge.get_question_by_idurl(question_idurl) end
  

end






