namespace :pikizi do

  desc "Load a domain"
  task :load_domain => :environment do
    unless ENV.include?("name")
      raise "usage: rake pikizi::load_domain name= a directory name in public/domains"
    end
    Knowledge.initialize_from_xml(ENV['name'])
  end


  desc "Recompute all aggregations based on opinions of all users on all products for all models"
  task :recompute_ratings => :environment do

    # compute
    # hash_k_f_p_aggregation[knowledge_idurl][feature_idurl][product_idurl] -> [nb_weighted, sum_weighted, [[user_idurl, reputation, note], ....]]

    # initialize for each ratable features
    # hash_k_f_p_aggregation[knowledge_idurl][feature_idurl][product_idurl] -> [0.0, 0.0, []]
    puts "initialization..."
    hash_k_f_p_aggregation = {}
    product_idurls = Product.xml_idurls
    Knowledge.xml_idurls.each do |knowledge_idurl|
      hash_f_p_aggregation = hash_k_f_p_aggregation[knowledge_idurl] = {}
      Knowledge.get_from_idurl(knowledge_idurl).hash_idurl_feature.each do |feature_idurl, feature|
        if feature.is_a?(FeatureRating)
          puts "setting up for feature #{feature_idurl} "
          hash_f_p_aggregation[feature_idurl] = product_idurls.inject({}) { |h, product_idurl| h[product_idurl] = [0.0, 0.0, []]; h }
        end
      end
    end

    # process each user
    puts "processing users..."
    User.xml_idurls.each do |user_idurl|
      user = User.create_from_xml(user_idurl)
      user.authored_opinions.each do |auth_opinion|
        k_idurl = auth_opinion.knowledge_idurl
        f_idurl = auth_opinion.feature_idurl
        p_idurl = auth_opinion.product_idurl
        raise "Wrong parameters #{auth_opinion.inspect}" unless k_idurl and f_idurl and p_idurl

        hash_f_p_aggregation = hash_k_f_p_aggregation[k_idurl]
        raise "knowledge idurl unknown #{k_idurl} #{hash_k_f_p_aggregation.inspect}" unless hash_f_p_aggregation

        hash_p_aggregation = hash_f_p_aggregation[f_idurl]
        raise "feature idurl unknown #{f_idurl}" unless hash_p_aggregation

        aggregation = hash_p_aggregation[p_idurl]
        raise "product idurl unknown #{p_idurl}" unless aggregation

        nb_weighted, sum_weighted, authors = aggregation
        nb_weighted += user.reputation
        sum_weighted += (user.reputation * auth_opinion.value)
        authors << [user.idurl, user.reputation, auth_opinion.value]
        hash_k_f_p_aggregation[k_idurl][f_idurl][p_idurl] = [nb_weighted, sum_weighted, authors]
      end
    end

    # write the result for each product
    puts "writing results..."
    Product.xml_idurls.each do |product_idurl|
      product = Product.get_from_idurl(product_idurl)

      hash_k_f_p_aggregation.each do |knowledge_idurl, hash_f_p_aggregation|
        hash_f_p_aggregation.each do |feature_idurl, hash_p_aggregation|
          if aggregation = hash_p_aggregation[product_idurl]
            nb_weighted, sum_weighted, authors = aggregation
            average_rating = (nb_weighted == 0.0 ? nil : sum_weighted / nb_weighted)
            values = authors.inject([average_rating]) do |l, (user_idurl, user_reputation, user_rating)|
              l << "#{user_idurl}(#{user_reputation})=#{user_rating}"
            end
            product.feature_data(knowledge_idurl, feature_idurl).values = values
          end
        end
      end

      product.save
    end

  end



  desc "Recompute all questions and choices counters for all knowledges"
  task :recompute_counters => :environment do

    # compute
    # hash_k_q_counter_presentation[knowledge_idurl][question_idurl] -> nb_presentation
    # hash_k_q_c_counter_ok[knowledge_idurl][question_idurl][choice_idurl] -> nb_ok

    # initialize...
    hash_k_q_counter_presentation = {}
    hash_k_q_c_counter_ok = {}

    Knowledge.xml_idurls.each do |knowledge_idurl|
      hash_q_c_counter_ok = hash_k_q_c_counter_ok[knowledge_idurl] = {}
      hash_q_counter_presentation = hash_k_q_counter_presentation[knowledge_idurl] = {}
      Knowledge.get_from_idurl(knowledge_idurl).questions.each do |question|
        hash_q_counter_presentation[question.idurl] = {:presentation => 0, :oo => 0}
        hash_q_c_counter_ok[question.idurl] = {}
        question.choices.each do |choice|
          hash_q_c_counter_ok[question.idurl][choice.idurl] = 0
        end
      end
    end

    # process each user
    User.xml_idurls.each do |user_idurl|
      user = User.create_from_xml(user_idurl)
      user.quiz_instances.each do |quiz_instance|
        quiz_instance.hash_answered_question_answers.each do |question_idurl, answers|
          answer = answers.last
          knowledge_idurl = answer.knowledge_idurl
          puts "knowledge_idurl=#{knowledge_idurl}, question_idurl=#{question_idurl}"
          hash_k_q_counter_presentation[knowledge_idurl][question_idurl][:presentation] += 1
          hash_k_q_counter_presentation[knowledge_idurl][question_idurl][:oo] += 1 unless answer.has_opinion?
          answer.choice_idurls_ok.each do |choice_idurl_ok|
            hash_k_q_c_counter_ok[knowledge_idurl][question_idurl][choice_idurl_ok] += 1
          end
        end
      end
    end


    # write the results in knowledge files
    hash_k_q_counter_presentation.each do |knowledge_idurl, hash_q_counter_presentation|
      knowledge = Knowledge.create_from_xml(knowledge_idurl)
      hash_q_counter_presentation.each do |question_idurl, counters|
        question = knowledge.get_question_by_idurl(question_idurl)
        question.nb_presentation_static = counters[:presentation]
        question.nb_oo_static = counters[:oo]
        # write in cache...
        Knowledge.counter_question_presentation(knowledge_idurl, question_idurl, :initialize => counters[:presentation])
        Knowledge.counter_question_oo(knowledge_idurl, question_idurl, :initialize => counters[:oo])

        hash_k_q_c_counter_ok[knowledge_idurl][question_idurl].each do |choice_idurl, counter_ok|
          choice = question.get_choice_from_idurl(choice_idurl)
          choice.nb_ok_static = counter_ok
          # write in cache...
          Knowledge.counter_choice_ok(knowledge_idurl, question_idurl, choice_idurl, :initialize => counter_ok)
        end
      end
      knowledge.save
    end

  end


end
