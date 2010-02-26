module ReviewsHelper

  def origin_review(review)
    l = []
    l << "by #{review.author}" if review.author
    l << "from #{review.source}" if review.source
    s = l.join(' ')
    s = link_to(s, review.source_url) if review.source_url
    s
  end

  def dimension_feature_related(knowledge, review_id, paragraph_number)
    select_tag("feature_related", options_for_select(dimension_feature(knowledge, :related)))
  end

  #mode is either :comparator or :related
  def dimension_feature(knowledge, mode)
    l = (mode == :comparator ? [["",""]] : [])
    knowledge.each_feature do |feature|
      l << [feature.label_select_tag, feature.idurl] if feature.is_compatible_grammar(mode)
    end
    l
  end

  def dimension_rating(knowledge, review_id, paragraph)
    key_overall_rating = "overall_rating"
    options = knowledge.feature_ratings.collect {|f| [f.label.gsub("Rating", ""), f.idurl]}
    options.sort! { |f1, f2| f1.first <=> f2.first }
    overall = options.detect {|f| f.last == key_overall_rating }
    options.delete(overall)
    options = [["Overall", key_overall_rating]].concat(options)
    select_tag("dimension_rating", options_for_select(options) )
  end

  def dimension_product(knowledge, except_pidurl=nil)
    knowledge.products.collect {|p| [p.label, p.idurl] }.select { |plabel, pidurl| pidurl != except_pidurl }.sort {|o1,o2| o1.first <=> o2.first }
  end

end
