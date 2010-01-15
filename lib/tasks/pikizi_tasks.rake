namespace :pikizi do

  desc "reset the Database"
  task :reset_db => :environment do
    Root.reset_db
  end

  desc "Load a domain"
  task :domain_load_xml => :environment do
    unless ENV.include?("name")
      raise "usage: rake pikizi::load_domain name= a directory name in public/domains"
    end
    Knowledge.initialize_from_xml(ENV['name'])
  end

  desc "Check consistency of a domain"
  task :domain_quality_check => :environment do
    unless ENV.include?("name")
      raise "usage: rake pikizi::domain_quality_check name= a directory name in public/domains"
    end
    doc = XML::Document.file("#{ENV['name']}/knowledge/knowledge.xml")
    schema = XML::Schema.new("/schemas/knowledge.xsd")
    doc.validate_schema(schema) do |message, flag|
      puts "#{flag} #{message}"
    end
  end

  desc "Generate reviews in database based on features values"
  task :reviews_load_features => :environment do
    k = get_knowledge
    # destroy previous automatic reviews
    # analyze the model and generates reviews objects, saved in DB
    compute_rating(k)
  end

  desc "Generate reviews from amazons"
  task :reviews_load_amazon => :environment do
    k = get_knowledge
    # destroy previous automatic reviews
    # analyze the model and geenrates reviews objects, saved in DB
    k.products.each { |product| product.create_amazon_reviews(k) }     
    compute_rating(k)
  end

  desc "Add xml reviews to the database"
  task :reviews_load_xml => :environment do
    k = get_knowledge
    # destroy the previous reviews  if exists
    # read review xml files and create objects in DB
    compute_rating(k)
  end

  desc "recompute weights after an update to knowledge, products or questions"
  task :notify_update_model => :environment do
    compute_weights(get_knowledge)
  end

  desc "CRON: Take into account answers and recompute question's proba"
  task :compute_answers => :environment do

    # read all answers, create proba
    # compute
    # hash_q_counter_presentation[question_idurl] -> nb_presentation
    # hash_q_c_counter_ok[question_idurl][choice_idurl] -> nb_ok

    # initialize...
    hash_q_counter_presentation = {}
    hash_q_c_counter_ok = {}
    questions = Question.find(:all)
    questions.each do |question|
      hash_q_counter_presentation[question.idurl] = {:presentation => 0, :oo => 0}
      hash_q_c_counter_ok[question.idurl] = {}
      question.choices.each do |choice|
        hash_q_c_counter_ok[question.idurl][choice.idurl] = 0
      end
    end

    # process each user
    User.find(:all).each do |user|
      user.quizze_instances.each do |quizze_instance|
        quizze_instance.hash_answered_question_answers.each do |question_idurl, answers|
          answer = answers.last
          puts "question_idurl=#{question_idurl}"
          hash_q_counter_presentation[question_idurl][:presentation] += 1
          hash_q_counter_presentation[question_idurl][:oo] += 1 unless answer.has_opinion?
          answer.choice_idurls_ok.each do |choice_idurl_ok|
            hash_q_c_counter_ok[question_idurl][choice_idurl_ok] += 1
          end
        end
      end
    end

    # write the results in questions, recompte distribution and save
    hash_q_counter_presentation.each do |question_idurl, counters|
      question = questions.detect? {|q| q.idurl == question_idurl}
      question.nb_presentation = counters[:presentation]
      question.nb_oo = counters[:oo]

      hash_q_c_counter_ok[question_idurl].each do |choice_idurl, counter_ok|
        choice = question.get_choice_from_idurl(choice_idurl)
        choice.nb_ok = counter_ok
      end
      question.compute_distribution
      question.save
    end

  end


  # ========================================================================================


  def get_knowledge
    knowledge_idurl = ENV.include?("name") ? ENV['name'] : "cell_phones"
    Knowledge.load(knowledge_idurl)
  end

  # recompute all rating and update distributions
  def compute_ratings(knowledge)
    # read reviews in database and compute aggregated rating
    compute_weights(knowledge)
  end

  # recompute all vertors pidurl -> weight per question/choice
  def compute_weights(knowledge)
    # compute weight for each question using the evaluator
    Question.find(:all).each do |question|
      # recompute weights, compute distribution and save the question
      question.generate_choices_pidurl2weight(knowledge)
      # quality check
      question.choices.each { |choice| choice.pidurl2weight.check_01 }
    end
  end


end
