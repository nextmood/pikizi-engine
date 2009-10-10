namespace :pikizi do


  desc "Recompute all aggregations based on opinions of all users on all products for all models"
  task :recompute_ratings => :environment do

    # compute
    # hash_k_f_p_aggregation[knowledge_key][feature_key][product_key] -> [nb_weighted, sum_weighted, [[user_key, reputation, note], ....]]

    # initialize for each ratable features
    # hash_k_f_p_aggregation[knowledge_key][feature_key][product_key] -> [0.0, 0.0, []]
    puts "initialization..."
    hash_k_f_p_aggregation = {}
    product_keys = Pikizi::Product.xml_keys
    Pikizi::Knowledge.xml_keys.each do |knowledge_key|
      hash_f_p_aggregation = hash_k_f_p_aggregation[knowledge_key] = {}
      Pikizi::Knowledge.get_from_cache(knowledge_key).hash_key_feature.each do |feature_key, feature|
        if feature.is_a?(Pikizi::FeatureRating)
          puts "setting up for feature #{feature_key} "
          hash_f_p_aggregation[feature_key] = product_keys.inject({}) { |h, product_key| h[product_key] = [0.0, 0.0, []]; h }
        end
      end
    end

    # process each user
    puts "processing users..."
    Pikizi::User.xml_keys.each do |user_key|
      user = Pikizi::User.create_from_xml(user_key)
      user.authored_opinions.each do |auth_opinion|
        k_key = auth_opinion.knowledge_key
        f_key = auth_opinion.feature_key
        p_key = auth_opinion.product_key
        raise "Wrong parameters #{auth_opinion.inspect}" unless k_key and f_key and p_key

        hash_f_p_aggregation = hash_k_f_p_aggregation[k_key]
        raise "knowledge key unknown #{k_key} #{hash_k_f_p_aggregation.inspect}" unless hash_f_p_aggregation

        hash_p_aggregation = hash_f_p_aggregation[f_key]
        raise "feature key unknown #{f_key}" unless hash_p_aggregation

        aggregation = hash_p_aggregation[p_key]
        raise "product key unknown #{p_key}" unless aggregation

        nb_weighted, sum_weighted, authors = aggregation
        nb_weighted += user.reputation
        sum_weighted += (user.reputation * auth_opinion.value)
        authors << [user.key, user.reputation, auth_opinion.value]
        hash_k_f_p_aggregation[k_key][f_key][p_key] = [nb_weighted, sum_weighted, authors]
      end
    end

    # write the result for each product
    puts "writing results..."
    Pikizi::Product.xml_keys.each do |product_key|
      product = Pikizi::Product.get_from_cache(product_key)

      hash_k_f_p_aggregation.each do |knowledge_key, hash_f_p_aggregation|
        hash_f_p_aggregation.each do |feature_key, hash_p_aggregation|
          if aggregation = hash_p_aggregation[product_key]
            nb_weighted, sum_weighted, authors = aggregation
            average_rating = (nb_weighted == 0.0 ? nil : sum_weighted / nb_weighted)
            values = authors.inject([average_rating]) do |l, (user_key, user_reputation, user_rating)|
              l << "#{user_key}(#{user_reputation})=#{user_rating}"
            end
            product.feature_data(knowledge_key, feature_key).values = values
          end
        end
      end

      product.save
    end

  end



  desc "Recompute all questions and choices counters for all knowledges"
  task :recompute_counters => :environment do

    # compute
    # hash_k_q_counter_presentation[knowledge_key][question_key] -> nb_presentation
    # hash_k_q_c_counter_ok[knowledge_key][question_key][choice_key] -> nb_ok

    # initialize...
    hash_k_q_counter_presentation = {}
    hash_k_q_c_counter_ok = {}

    Pikizi::Knowledge.xml_keys.each do |knowledge_key|
      hash_q_c_counter_ok = hash_k_q_c_counter_ok[knowledge_key] = {}
      hash_q_counter_presentation = hash_k_q_counter_presentation[knowledge_key] = {}
      Pikizi::Knowledge.get_from_cache(knowledge_key).questions.each do |question|
        hash_q_counter_presentation[question.key] = {:presentation => 0, :oo => 0}
        hash_q_c_counter_ok[question.key] = {}
        question.choices.each do |choice|
          hash_q_c_counter_ok[question.key][choice.key] = 0
        end
      end
    end

    # process each user
    Pikizi::User.xml_keys.each do |user_key|
      user = Pikizi::User.create_from_xml(user_key)
      user.quiz_instances.each do |quiz_instance|
        quiz_instance.hash_answered_question_answers.each do |question_key, answers|
          answer = answers.last
          knowledge_key = answer.knowledge_key
          puts "knowledge_key=#{knowledge_key}, question_key=#{question_key}"
          hash_k_q_counter_presentation[knowledge_key][question_key][:presentation] += 1
          hash_k_q_counter_presentation[knowledge_key][question_key][:oo] += 1 unless answer.has_opinion?
          answer.choice_keys_ok.each do |choice_key_ok|
            hash_k_q_c_counter_ok[knowledge_key][question_key][choice_key_ok] += 1
          end
        end
      end
    end


    # write the results in knowledge files
    hash_k_q_counter_presentation.each do |knowledge_key, hash_q_counter_presentation|
      knowledge = Pikizi::Knowledge.create_from_xml(knowledge_key)
      hash_q_counter_presentation.each do |question_key, counters|
        question = knowledge.get_question_from_key(question_key)
        question.nb_presentation_static = counters[:presentation]
        question.nb_oo_static = counters[:oo]
        # write in cache...
        Pikizi::Knowledge.counter_question_presentation(knowledge_key, question_key, :initialize => counters[:presentation])
        Pikizi::Knowledge.counter_question_oo(knowledge_key, question_key, :initialize => counters[:oo])

        hash_k_q_c_counter_ok[knowledge_key][question_key].each do |choice_key, counter_ok|
          choice = question.get_choice_from_key(choice_key)
          choice.nb_ok_static = counter_ok
          # write in cache...
          Pikizi::Knowledge.counter_choice_ok(knowledge_key, question_key, choice_key, :initialize => counter_ok)
        end
      end
      knowledge.save
    end

  end


end
