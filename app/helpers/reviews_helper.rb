module ReviewsHelper




  def dimension_rating(a_knowledge, review_id, paragraph)
    key_overall_rating = "overall_rating"
    options = a_knowledge.feature_ratings.collect {|f| [f.label.gsub("Rating", ""), f.idurl]}
    options.sort! { |f1, f2| f1.first <=> f2.first }
    overall = options.detect {|f| f.last == key_overall_rating }
    options.delete(overall)
    options = [["Overall", key_overall_rating]].concat(options)
  end

  def dimension_product(a_knowledge, options = {})
    raise "error bad a_knowledge " unless a_knowledge.id
    except_pids = (options[:minus] || [])
    except_pids = [except_pids] unless except_pids.is_a?(Array)
    l_products = a_knowledge.products
    l_products.delete_if { |p| except_pids.include?(p.id) }
    l_products_tupple = l_products.collect {|p| [p.label, (options[:key_idurl] ? p.idurl : p.id)] }.sort {|o1,o2| o1.first <=> o2.first }
    header = []
    header << [options[:title], "default_title"] if options[:title]    
    header << ["all products", "all_products"] if options[:extra]
    header.concat(l_products_tupple)
    header
  end

end
