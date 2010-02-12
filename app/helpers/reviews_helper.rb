module ReviewsHelper

  def origin_review(review)
    l = []
    l << "by #{review.author}" if review.author
    l << "from #{review.source}" if review.source
    s = l.join(' ')
    s = link_to(s, review.source_url) if review.source_url
    s
  end

  def dimension_operande1(knowledge, review_id, paragraph_number)
    select_tag("operande1_#{review_id}_#{paragraph_number}", options_for_select([["product", :product]].concat(dimension_feature(knowledge, :comparator))))
  end

  def dimension_operator(knowledge, review_id, paragraph_number, operande1_key)
    if operande1_key == :product
      "named"
    else
      feature = knowledge.get_feature_by_idurl(operande1_key)
      select_tag("operator_#{review_id}_#{paragraph_number}", options_for_select(feature.get_operators) )        
    end
  end

  def dimension_operande2(knowledge, review_id, paragraph_number, operande1_key, operator_key)
    if operande1_key == :product
      # a list of product minus the current one
      select_tag("operande2_#{review_id}_#{paragraph_number}", options_for_select(dimension_product(knowledge)) )
    else
      # operande1_key is a feature
      " filter for feature = #{text_field_tag("operande2_#{review_id}_#{paragraph_number}", "to be completed")}"
    end

  end

  def dimension_feature_related(knowledge, review_id, paragraph_number)
    select_tag("feature_related_#{review_id}_#{paragraph_number}", options_for_select(dimension_feature(knowledge, :related)))
  end

  #mode is either :comparator or :related
  def dimension_feature(knowledge, mode)
    knowledge.each_feature_collect do |feature|
      ["feature #{feature.label_select_tag}", feature.id] if feature.is_compatible_grammar(mode)
    end.compact
  end

  def dimension_rating(knowledge, review_id, paragraph_number)
    options = knowledge.feature_ratings.collect {|f| [f.label, f.idurl]}
    options.sort! { |f1, f2| f1.first <=> f2.first }
    overall = options.detect {|f| f.last == "overall_rating" }
    options.delete(overall)
    options = [overall].concat(options)
    select_tag("dimension_rating_#{review_id}_#{paragraph_number}", options_for_select(options) )
  end

  def dimension_product(knowledge, except_pidurl=nil)
    knowledge.products.collect {|p| [p.label, p.idurl] }.select { |plabel, pidurl| pidurl != except_pidurl }.sort {|o1,o2| o1.first <=> o2.first }
  end
  
end
