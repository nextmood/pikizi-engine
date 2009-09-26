namespace :pikizi do


  desc "Recompute all aggregations based on opinions of all users on all products for all models"
  task :recompute_ratings => :environment do

    # compute
    # rating[knowledge_key][feature_key][product_key] -> [nb_weighted, sum_weighted, [[user_key, reputation, note], ....]]

    # initialize for each ratable features
    # rating[knowledge_key][feature_key][product_key] -> [0.0, 0.0, []]
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
    Pikizi::User.xml_keys.each do |user_key|
      user = Pikizi::User.get_from_cache(user_key)
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

  
end
