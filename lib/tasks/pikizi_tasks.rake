namespace :pikizi do

  desc "reset the Database"
  task :reset_db => :environment do

    Question.delete_all
    Quizze.delete_all
    Product.delete_all
    Opinion.delete_all
    Review.delete_all
    Paragraph.delete_all
    Knowledge.delete_all

    User.delete_all
    User.create_default_users

#    User.all.each do |user|
#      user.quizze_instances = []
#      user.reviews = []
#      user.save
#    end

    k = Knowledge.initialize_from_xml(ENV.include?("name") ? ENV['name'] : "cell_phones")

    # create all reviews from xml located in domain/reviews directory
    Review::FileXml.create_with_opinions(k)

    # create all reviews from amazon web site for all products
    Review::FromAmazon.create_with_opinions_4_all_products(k)

    compute_ratings(k)

    "database reset"
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
    compute_ratings(k)
  end

  desc "Generate reviews from amazon"
  task :reviews_load_amazon => :environment do
    k = get_knowledge
    # destroy previous automatic reviews
    # analyze the model and geenrates reviews objects, saved in DB
    Review::FromAmazon.create_with_opinions_4_all_products(k)
    compute_ratings(k)
  end

  desc "Add xml reviews to the database"
  task :reviews_load_xml => :environment do
    k = get_knowledge
    # destroy the previous reviews  if exists
    # read review xml files and create objects in DB
    Opinion.initialize_from_xml(k)
    compute_ratings(k)
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
    questions = Question.all
    questions.each do |question|
      hash_q_counter_presentation[question.idurl] = {:presentation => 0, :oo => 0}
      hash_q_c_counter_ok[question.idurl] = {}
      question.choices.each do |choice|
        hash_q_c_counter_ok[question.idurl][choice.idurl] = 0
      end
    end

    # process each user
    User.all.each do |user|
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

  
  desc "compute aggregation of dimension and usage from opinions"
  task :compute_aggregation => :environment do
    # cleanup opinion (to be remove later...)
    Knowledge.first(:idurl => "cell_phones").compute_aggregation
  end

  desc "maj db"
  task :maj_db => :environment do
    # cleanup opinion (to be remove later...)
    knowledge = get_knowledge
    all_products = knowledge.products

    Opinion.all(:paragraph_id => nil).each { |o| o.update_attributes(:paragraph_id => o.review.paragraphs.first.id) if o.paragraph_id.nil? and o.review.paragraphs.size > 0 }


    Comparator.all.each do  |c|
      unless compare_to = c.products_filters_for("compare_to").first
        if  c.predicate == "productIs(:all_products)"
          pf = ProductsByShortcut.create(:shortcut_selector => "all_products", :opinion_id => c.id, :products_selector_dom_name => "compare_to")
          c.products_filters << pf; c.save
        end
      end
      compare_to.update_labels  if compare_to    
    end

    Opinion.all.each {|o| o.compute_product_ids_related(all_products) }

    puts "done..."

  end

  # ========================================================================================


  def get_knowledge
    knowledge_idurl = ENV.include?("name") ? ENV['name'] : "cell_phones"
    Knowledge.load_db(knowledge_idurl)
  end


  # recompute all vertors pidurl -> weight per question/choice
  def compute_weights(knowledge)
    # compute weight for each question using the evaluator
    knowledge.questions.each do |question|
      # recompute weights, compute distribution and save the question
      question.generate_choices_pidurl2weight(knowledge)
      # quality check
      question.choices.each { |choice| choice.pidurl2weight.check_01 }
    end

    # pre compute number of questions, reviews, quizzes, products etc... and save the knowledge
    knowledge.compute_counters
  end



end
