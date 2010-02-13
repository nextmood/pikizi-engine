namespace :pikizi do

  desc "reset the Database"
  task :reset_db => :environment do

    Question.delete_all
    Quizze.delete_all
    Product.delete_all
    Opinion.delete_all
    Review.delete_all
    Knowledge.delete_all

    User.delete_all
    User.create_default_users

#    User.find(:all).each do |user|
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
    # hash_p_f_c_aggregation[product_idurl][feature_idurl][category] -> [nb_weighted, sum_weighted]

    # initialize for each ratable features
    # hash_p_f_c_aggregation[product_idurl][feature_idurl][category]  -> [0.0, 0.0]
    puts "initialization... for model #{knowledge.label}"
    hash_p_f_c_aggregation = knowledge.products.inject({}) do |h, product|
      h[product.idurl] = knowledge.feature_ratings.inject({}) do |h1, feature_rating|
        h1[feature_rating.idurl] = Review.categories.inject({}) { |h2, (category, weight)| h2[category] = [0.0, 0.0]; h2 }
        h1
      end
      h
    end

    # process each review objects
    puts "processing reviews..."
    Review.find(:all).each do |review|
      if review.knowledge_idurl == knowledge.idurl
        p_idurl = review.product_idurl
        review.opinions.each do |opinion|
          f_idurl = opinion.feature_idurl
          nb_weighted, sum_weighted = hash_p_f_c_aggregation[p_idurl][f_idurl][review.get_category]
          raise "error unknown feature=#{f_idurl} for product=#{p_idurl} and category=#{review.get_category}" unless nb_weighted and sum_weighted

          rating_01 = Root.rule3(opinion.rating, opinion.min_rating, opinion.max_rating)
          nb_weighted += review.get_reputation
          sum_weighted += (review.get_reputation * rating_01)

          hash_p_f_c_aggregation[p_idurl][f_idurl][review.get_category] = [nb_weighted, sum_weighted]
        end
      end
    end

    # write the result for each  and products
    puts "computing and writing results..."
    knowledge.products.each do |product|
      knowledge.each_feature_rating do |feature_rating|

        # compute the average rating for each product/feature/category
        Review.categories.each do |category, weight|
          raise "error no product #{product.idurl}" unless hash_p_f_c_aggregation[product.idurl]
          raise "error no feature #{feature_rating.idurl} for product  #{product.idurl}" unless hash_p_f_c_aggregation[product.idurl][feature_rating.idurl]
          raise "error no category #{category} for feature #{feature_rating.idurl} for product  #{product.idurl}" unless hash_p_f_c_aggregation[product.idurl][feature_rating.idurl][category]

          nb_weighted, sum_weighted = hash_p_f_c_aggregation[product.idurl][feature_rating.idurl][category]
          average_rating = (nb_weighted == 0.0 ? nil : sum_weighted / nb_weighted)
          hash_p_f_c_aggregation[product.idurl][feature_rating.idurl][category] = average_rating
        end

        # compute the global rating for this product/feature (weighted average of category rating)
        sum_weighted, nb_weighted = Review.categories.inject([0.0, 0.0]) do |(sw, nw), (category, category_weight)|
          if rating = hash_p_f_c_aggregation[product.idurl][feature_rating.idurl][category]
            [sw + rating * category_weight, nw + category_weight]
          else
            [sw, nw]
          end
        end
        average_rating_global = (nb_weighted == 0.0 ? nil : sum_weighted / nb_weighted)
        hash_p_f_c_aggregation[product.idurl][feature_rating.idurl][:global_rating] = average_rating_global

        # save the average rating for each category for this product
        product.set_value(feature_rating.idurl, average_rating_global)
        puts "#{product.idurl}/#{feature_rating.idurl}=#{average_rating_global}" if average_rating_global

      end

      product.save
    end

    # recompute weights...
    compute_weights(knowledge)
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
    k.compute_counters
  end


end
