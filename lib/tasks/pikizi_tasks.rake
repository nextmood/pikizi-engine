namespace :pikizi do



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


    puts "2) update reviews state to empty ..."
    Review.all.each { |r| check_update(r, r.update_attributes(:state => "empty", :written_at => (r.written_at || (Date.today - 900))))  }
    puts "3) update products release date..."
    Product.all.each { |p| check_update(p, p.update_attributes(:knowledge_id => knowledge.id,
                                               :release_date => (p.get_value("release_date") || (Date.today - 1000)))) }
    puts "4) create neutral tips..."
    Neutral.create_from_neutral_tips
    puts "5) update opinions state to draft..."

    Opinion.all.each { |o| check_update(o, o.update_attributes(:state => "draft", :written_at => o.review.written_at)) }

    puts "6) update misc..."

    Quizze.all.each { |q| check_update(q, q.update_attributes(:knowledge_id => knowledge.id))  unless q.knowledge_id == knowledge.id}
    Question.all.each { |q| check_update(q, q.update_attributes(:knowledge_id => knowledge.id)) unless q.knowledge_id == knowledge.id}

    puts "7) update paragraphs state to empty..."

    Paragraph.all.each { |p| check_update(p, p.update_attributes(:state => "empty")) }



    puts "7-a) update reviews opinions vs paragraph opinions ..."
    Review.all.each do |r|
      r.update_attributes(:opinions => r.opinions_through_paragraphs)
    end

    
    puts "8) update products filter..."

    # recompute labels of products filters
    ProductsFilter.all.each { |pf| pf.preceding_operator = "or"; pf.update_labels_debug; pf.save; }

    all_products = knowledge.get_products
    puts "9) update opinions state final..."

    Opinion.all.each { |o| o.correct!; o.update_status(all_products) }
    Opinion.all.each { |o| begin o.accept!; rescue ; end }

    puts "10) update paragraphs state final..."

    Paragraph.all.each { |p| p.update_status }

    puts "11) update reviews state final..."    

    Review.all.each { |r| r.update_status }

    true
  end

  def check_update(o, x)
    raise "wrong update #{o.errors.inspect}" unless x
  end

  # ========================================================================================


  def get_knowledge
    knowledge_idurl = ENV.include?("name") ? ENV['name'] : "cell_phones"
    Knowledge.first(:idurl => knowledge_idurl)
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
  end



end
