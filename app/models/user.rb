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

  def self.create_default_users
   [  { :rpx_email => "info@nextmood.com", :rpx_username => "fpatte", :rpx_name => "Franck PATTE", :role => "admin", :category => "user", :rpx_identifier => "http://pipo_for_developper" },
      { :rpx_email => "", :rpx_username => "FranckPATTE", :rpx_name => "Franck PATTE", :role => "user", :category => "user", :rpx_identifier => "http://www.facebook.com/profile.php?id=562704993" },
      { :rpx_email => "", :rpx_username => "JulienSalanon", :rpx_name => "Julien Salanon", :role => "user", :category => "user", :rpx_identifier => "http://www.facebook.com/profile.php?id=576451838" },
      { :rpx_email => "gareyte@gmail.com", :rpx_username => "gareyte", :rpx_name => "gareyte", :role => "user", :category => "user", :rpx_identifier => "https://www.google.com/accounts/o8/id?id=AItOawlD3frzF_xhWS5QTyCKibuTIDBNCio_8I0" },
      { :rpx_email => "cpatte@gmail.com", :rpx_username => "cpatte", :rpx_name => "cpatte", :role => "admin", :category => "user", :rpx_identifier => "https://www.google.com/accounts/o8/id?id=AItOawnpmDf5QToZ19rH88JKkxvekvh3Ve9HAmA" },
      { :rpx_email => "eric.degoul@gmail.com", :rpx_username => "eric.degoul", :rpx_name => "eric.degoul", :role => "unauthorised", :category => "user", :rpx_identifier => "https://www.google.com/accounts/o8/id?id=AItOawk_GgNV2dsjnPAvVe5rcxdPT0vPD7-qmiQ" },
      { :rpx_email => "", :rpx_username => "EricDegoul", :rpx_name => "Eric Degoul", :role => "user", :category => "user", :rpx_identifier => "http://www.facebook.com/profile.php?id=771667528" },
      { :rpx_email => "phclouin@yahoo.com", :rpx_username => "phclouin", :rpx_name => "phclouin", :role => "admin", :category => "expert", :rpx_identifier => "https://me.yahoo.com/a/DQGsE5AIpen1BT84wjDptBjnsMBZ#16c18" },
      { :rpx_email => "mr.gene.kim@gmail.com", :rpx_username => "mr.gene.kim", :rpx_name => "mr.gene.kim", :role => "unauthorised", :category => "user", :rpx_identifier => "https://www.google.com/accounts/o8/id?id=AItOawmn_Bt_gUemsxYfrj6LRniDCpALfuSFoSk" }
   ].each { |options| User.first_create(options) }
  end


  def is_authorized() !is_unauthorized end
  def is_admin() role == "admin" end
  def is_tester() role == "tester" end
  def is_unauthorized() role == "unauthorised" end

  def nb_quizze_instances() quizze_instances.size end
  def nb_reviews() reviews.size end


  def self.compute_idurl(rpx_email, rpx_identifier=nil)
    rpx_email = nil if rpx_email == ""
    Digest::MD5.hexdigest(
      if String.is_not_empty(rpx_email)
        rpx_email
      else      
        # extract id=something from the rpx_identifier
        # exemple: facebook http://www.facebook.com/profile.php?id=562704993
        service, external_id = rpx_identifier.extract_external_id
        raise "no id for this user" unless service and external_id
        "#{service}_#{external_id}"
      end
    )
  end

  # create a new user in the database, options:
  # :rpx_identifier  (mandatory)
  # :rpx_username (mandatory)
  # :rpx_email (mandatory)
  # :rpx_name  (default to username)
  # :rpx_role (default 'user')
  def self.first_create(options)
    options[:idurl] = User.compute_idurl(options[:rpx_email], options[:rpx_identifier])
    options[:rpx_role] ||= "user"
    options[:rpx_name] ||= options[:rpx_username]
    User.create( options )
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
  def get_latest_quizze_instance() QuizzeInstance.get_latest_quizze(self) end
  def create_quizze_instance(quizze) QuizzeInstance.create_for_quizze(quizze, self) end

  # step #1 user.record_answer
  # step #2 question.record_answer
  # step #2.1 choice.record_answer
  # step #3 trigger valide recommendations (quizze_instance.record_answer)
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
    new_review = Opinion.new
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
# parent is the user
class QuizzeInstance < Root

  include MongoMapper::EmbeddedDocument

  key :quizze_idurl, String
  key :created_at, Time  # when the QuizInstqnce was created
  key :closed_at, Time, :default => nil   # when the suer or system (time out) has closed this QuizzeInstance
  key :question_ids, Array

  many :answers
  many :affinities

  attr_accessor :user, :hash_answered_question_answers, :hash_pidurl_affinity

  def user() _root_document end
  def hash_answered_question_answers
    @hash_answered_question_answers ||= answers.inject({}) do |h, answer|
      (h[answer.question_idurl] ||= []) << answer
      h
    end
  end
  def hash_pidurl_affinity
    @hash_pidurl_affinity ||= affinities.inject({}) do |h, affinity|
      h[affinity.product_idurl] = affinity
      h
    end
  end

  def get_quizze() @quizze ||= Quizze.first(:idurl => quizze_idurl) end


  def generate_xml(top_node)
    node_quizze_instance = super(top_node)
    node_quizze_instance['quizze_idurl'] = quizze_idurl

    node_quizze_instance << (node_affinities = XML::Node.new('affinities'))
    hash_pidurl_affinity.each { |product_idurl, affinity| affinity.generate_xml(node_affinities) }

    node_quizze_instance['created_at'] = created_at.strftime(Root.default_datetime_format)
    node_quizze_instance['closed_at'] = closed_at.strftime(Root.default_datetime_format) if closed_at

    node_quizze_instance << (node_answered = XML::Node.new('answered'))
    puts "answers=#{answers.inspect}"
    answers.each do  |answer| answer.generate_xml(node_answered) end

    node_quizze_instance
  end

  # sort the affinities by ranking
  def sorted_affinities
    unless @sorted_affinities
      @sorted_affinities = hash_pidurl_affinity.collect { |product_idurl, affinity| affinity }
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

  def nb_products_ranked_at_most
    max_ranking_1 = 0
    max_ranking_12 = 0
    max_ranking_123 = 0
    sorted_affinities.each do |a|
      max_ranking_1 += (a.ranking == 1 ? 1 : 0)
      max_ranking_12 += (a.ranking <= 2 ? 1 : 0)
      max_ranking_123 += (a.ranking <= 3 ? 1 : 0)
    end
    if max_ranking_1 > 5
      max_ranking_1
    elsif max_ranking_12 > 5
      max_ranking_12
    else
      max_ranking_123
    end
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
      hash_pidurl2weight = question.delta_weight(answer)
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

  def quiz_instance() self._parent_document end

  def add(weight, question_weight)
    self.nb_weight += question_weight
    self.sum_weight += weight * question_weight
  end

  def product(knowledge) knowledge.get_product_by_idurl(product_idurl) end

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


  def self.nb_input_4_max_confidence() 5.0 end
  def confidence() @confidence ||= ([Affinity.nb_input_4_max_confidence, nb_weight].min / Affinity.nb_input_4_max_confidence) end

end



# describe an answer to a Question by a User during a Quizze Instance
# has answer ok assiociated
class Answer < Root

  include MongoMapper::EmbeddedDocument

  key :knowledge_idurl, String
  key :question_idurl, String # question
  key :choice_idurls_ok, Array
  key :time_stamp, Time

  def quiz_instance() self._document_parent end

  def generate_xml(top_node)
    node_answer = super(top_node)
    node_answer['knowledge_idurl'] = knowledge_idurl
    node_answer['question_idurl'] = question_idurl
    node_answer['choice_idurls_ok'] = choice_idurls_ok.join(',')
    node_answer['time_stamp'] = time_stamp.strftime(Root.default_datetime_format)
    node_answer
  end

  def has_opinion?() choice_idurls_ok.size > 0 end

  # return a list of choice object matching the answer of this user to the question
  def choices_ok(question) question.get_choice_ok_from_idurls(choice_idurls_ok) end

  def question(knowledge) knowledge.get_question_by_idurl(question_idurl) end
  

end






