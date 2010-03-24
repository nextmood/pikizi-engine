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


  # ========================================================================================


  def get_knowledge
    knowledge_idurl = ENV.include?("name") ? ENV['name'] : "cell_phones"
    Knowledge.load_db(knowledge_idurl)
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
    Review.all.each do |review|
      if review.knowledge_idurl == knowledge.idurl
        p_idurl = review.product_idurl
        review.opinions.each do |opinion|
          feature_rating_idurl = opinion.feature_rating_idurl
          nb_weighted, sum_weighted = hash_p_f_c_aggregation[p_idurl][feature_rating_idurl][review.category]
          raise "error unknown dimension_rating=#{feature_rating_idurl} for product=#{p_idurl} and category=#{review.category}" unless nb_weighted and sum_weighted

          rating_01 = Root.rule3(opinion.rating, opinion.min_rating, opinion.max_rating)
          nb_weighted += review.get_reputation
          sum_weighted += (review.get_reputation * rating_01)

          hash_p_f_c_aggregation[p_idurl][feature_rating_idurl][review.category] = [nb_weighted, sum_weighted]
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
    knowledge.compute_counters
  end

  # ==============================================================================================
  desc "recompute category for reviews"
  task :recompute_category => :environment do
    Review.all.each {|r| r.category = r.class.default_category; r.save }
    true
  end

  desc "clean up eric cretan reiews"
  task :eric_cretan => :environment do

    path = "public/domains/cell_phones/reviews/paragraph_eric"
    file_names = Root.get_entries(path).inject({}) do |h, entry|
      l = entry.split(".")
      product_name, source_name = l.first.split('-')
      h[product_name] ||= {}
      h[product_name][source_name] ||= [nil, nil]
      raise "error #{l.inspect}" unless l[1] == "txt"
      raise "error" if h[product_name][source_name][l.size-2]
      h[product_name][source_name][l.size-2] = entry
      h
    end

    # not referenced= nexus_one, nokia_E72, htc_magic, nokia_5235

    eric2product_idurl = { "Motorola_Droid" => "motorola_droid",
                             "Palm_Pre_Plus" => "palm_pre",
                             "Nexus_One" => "nexus_one",
                             "Droid_Eris" => "htc_droid_eris",
                             "Nokia_E72" => "nokia_e72",
                             "HTC_Magic" => "htc_magic",
                             "Nokia_5235" => "nokia_5235" }

    # un-used rating dimension
    # ["contacts_rating", "", "functionality_performance_rating", "", "security_management_rating", "storage_syncing_rating", "",  "music_rating", ""]

    eric2feature_idurl = {
             "overall" => "overall_rating",
             "functionality & performance" => "functionality & performance",
             "design & construction" => "design_construction_rating",
             "screen" => "screen_rating",
             "user interface" => "user_interface_rating",
             "keyboard & input" => "keyboard_input_rating",
             "controls & navigation" => "controls_navigation_rating",
             "camera" => "camera_rating",
             "video" => "video_rating",
             "battery life" => "battery_life_rating",
             "connectivity & internet experience" => "connectivity_internet_rating",
             "gps" => "gps_rating",
             "apps" => "apps_rating",
             "value" => nil,
             "messaging & emails & social networking" => "messaging_rating",
             "call functionality & quality" => "call_rating",
             "media" => "media_rating",
             "productivity" => "productivity_rating" }

    ericvalue2intensity = {
            "very positive" => {:intensity => 1.0, :is_mixed => false },
            "positive" => {:intensity => 0.5, :is_mixed => false} ,
            "neutral" => {:intensity => 0.0, :is_mixed => false} ,
            "negative" => {:intensity => -0.5, :is_mixed => false} ,
            "very negative" => {:intensity => -1.0, :is_mixed => false} ,
            "mixed" => {:intensity => 0.0, :is_mixed => true}
            }

    knowledge = Knowledge.first(:idurl => "cell_phones")
    # do the job for each complete review/analysis
    file_names.each do |product_name, sources|
      if product_idurl = eric2product_idurl[product_name]
        product = Product.first(:idurl => product_idurl)
        
        sources.each do | source_name, (file_review, file_opinions)|
          if file_review and file_opinions


            puts "processing review for #{product_name} source=#{source_name} file_review=#{file_review}  file_opinions=#{file_opinions}"

            file = File.new("#{path}/#{file_review}", "r")
            paragraphs = []
            while (line = file.gets)
              i = line.index("]\t")
              paragraphs <<  line[i+2..10000]
            end
            file.close
            content = paragraphs.collect { |p| "<p>#{p}</p>"}.join

            # create the review object
            review = Review::Inpaper.create(:product => product, :category => "expert", :product_idurl => product.idurl, :source => source_name, :written_at => Time.now, :knowledge_idurl => knowledge.idurl, :knowledge => knowledge, :summary => "#{content[0..40]} ..." , :content => content, :author => "ecrestan")

            # create the paragraphs
            paragraphs_generated = []
            paragraphs.each_with_index do |p, count|
              paragraphs_generated << Paragraph.create(:ranking_number => count, :content => p, :review_id => review.id)
            end
            review.paragraphs = paragraphs_generated

            file = File.new("#{path}/#{file_opinions}", "r")
            while (line = file.gets)
              # "positive", "negative", "very positive", "neutral", "mixed", "very negative"

              opinion = line.strip.split("\t")
              index_paragraph = Integer(opinion[0])
              paragraph =  paragraphs_generated[index_paragraph]

              dimension_idurl_1 = eric2feature_idurl[opinion[1]]
              value_1 = opinion[3]
              if dimension_idurl_1  and value_1 and value_1 != ""
                Opinion::Tip.create({:paragraph => paragraph, :review => review, :feature_rating_idurl => dimension_idurl_1}.merge(ericvalue2intensity[value_1]))
                puts "opinion p#{index_paragraph} #{dimension_idurl_1}=#{value_1}"  if dimension_idurl_1
              end

              dimension_idurl_2 = eric2feature_idurl[opinion[2]]
              value_2 = opinion[4]
              if dimension_idurl_2 and  value_2 and value_2 != ""
                Opinion::Tip.create({:paragraph => paragraph, :review => review, :feature_rating_idurl => dimension_idurl_2 }.merge(ericvalue2intensity[value_2]))
                puts "opinion p#{index_paragraph} #{dimension_idurl_2}=#{value_2}"  if dimension_idurl_2
              end

            end
            file.close
          end
        end
      end
    end
    true
  end

  desc "resync database"
  task :resync_database => :environment do
    Review.all.each { |r| (r.product.reviews << r; r.product.save; puts "update product=#{r.product.idurl}") unless r.product.reviews.include?(r) }
    Opinion.all.each { |o| (o.review.opinions << o; o.review.save; puts "update review for product=#{o.review.product.idurl}/#{o.review.category}") unless o.review.opinions.include?(o) }
  end

  desc "update database"
  task :update_database => :environment do

    knowledge = Knowledge.first.link_back
    knowledge.categories_map = [["Cell Phone", "cell_phone"],
                                ["Smartphone", "smartphone"],
                                ["Messaging phone", "messaging_phone"],
                                ["Camera phone", "camera_phone"],
                                ["Media phone", "media_phone"]]
    #knowledge.save
    feature_category = knowledge.get_feature_by_idurl("phone_category")
    Product.all.each do |product|
      # 1) retrieve images...
#      product.fillup_image_ids
#      product.fillup_others
#      puts "#{product.image_ids.size} images for product #{product.idurl}"


      #product.save

      # 4) Creating Dimension Objects...
      #Dimension.import

      # 5) Creating Specification Objects...
      #Specification.delete_all;
      #knowledge.features.each {|f| f.create_specification(knowledge.id) }

      #retrieve the intensity symbol
      #Opinion::Tip.convert
     
    end

    Review.all.each do |review|
      review.product_ids = [review.product_id]
      review.product_idurls = [review.product_idurl]
      review.save
    end
    true
  end

end
