require 'xml'
require 'mongo_mapper'
require 'specification'
require 'offer'
require 'products_filter'

#require 'graphviz'

class Knowledge < Root

  include MongoMapper::Document

  key :idurl, String # unique url
  key :label, String
  key :last_aggregation_timestamp, Time

  # --------- Dimensions of rating (hierarchical structure, one root) -----------------------
  many :dimensions, :polymorphic => true

  # build the dimension hierarchical structure and return the top level dimension
  # instance cached, use :reset => true to recompute
  def dimension_root(options={}) tree_manager(:dimensions, options.merge(:one_root => true)) end
  def get_dimension_by_id(id) tree_manager(:dimensions, :by_id => id) end
  def get_dimension_by_idurl(idurl) tree_manager(:dimensions, :by_idurl => idurl) end
  def nb_dimensions() dimensions.count end

  # --------- Specifications (hierarchical structure, multiple roots) ---------------
  many :specifications, :polymorphic => true

  # build the specification hierarchical structure and return the top level specifications
  # instance cached, use :reset => true to recompute
  def specification_roots(options={}) tree_manager(:specifications, options.merge(:all_roots => true)) end
  def get_specification_by_id(id) tree_manager(:specifications, :by_id => id) end
  def get_specification_by_idurl(idurl) tree_manager(:specifications, :by_idurl => idurl) end
  def nb_specifications() specifications.count end
  
  # --------- products attached to this knowledge  ---------------
  many :products
  def get_products() list_manager(:products, :all => true) end
  def get_product_by_id(id) list_manager(:products, :by_id => id) end
  def get_product_by_idurl(idurl) list_manager(:products, :by_idurl => idurl) end
  def nb_products() products.count end

  # --------- reviews attached to this knowledge  ---------------
  many :reviews

  # --------- drivers (source of data) attached to this knowledge  ---------------
  many :drivers

  # --------- synonyms (for textmining) attached to this knowledge  ---------------
  many :synonyms

  # --------- usages attached to this knowledge  (xxx) ---------------
  many :usages
  def nb_usages() usages.count end
  
  # --------- questions attached to this knowledge  ---------------
  many :questions
  def get_questions() list_manager(:questions, :all => true) end
  def get_question_by_id(id) list_manager(:questions, :by_id => id) end
  def get_question_by_idurl(idurl) list_manager(:questions, :by_idurl => idurl) end
  def nb_questions() questions.count end

  # --------- quizzes attached to this knowledge  ---------------
  many :quizzes, :class_name => "Quizze"
  def get_quizzes() list_manager(:quizzes, :all => true) end
  def get_quizze_by_id(id) list_manager(:quizzes, :by_id => id) end
  def get_quizze_by_idurl(idurl) list_manager(:quizzes, :by_idurl => idurl) end
  def nb_quizzes() get_quizzes.size end

  # ---------------------------------------------------------------------------------------


  key :question_idurls, Array
  #def questions() @questions ||= Question.all(:idurl => question_idurls)  end
  def questions_sorted_by_desc_discrimination(pidurls, user=nil)
    questions.sort { |q1, q2| q2.discrimination(user, pidurls) <=> q1.discrimination(user, pidurls) }
  end



  key :quizze_idurls, Array
  def quizzes() @quizzes ||= Quizze.all(:idurl => quizze_idurls) end


  
  timestamps!


  def self.all_key_label(options={})
    @@all_key_label ||= Knowledge.all.collect {|k| [k.idurl, k.label] }
    if options[:only] == :idurl
      @@all_key_label.collect { |idurl, label| idurl }
    elsif options[:only] == :label
      @@all_key_label.collect { |idurl, label| label }
    else
      @@all_key_label
    end
  end

  # recompute all states of reviews and paragraph of this knowledge
  # option -> recompute opinions.status
  def recompute_all_states(options={})
    reviews.each_with_index do |review, i|
      t0 = Time.now
      nb_opinions = 0
      review.paragraphs.each do |paragraph|
        if options[:also_opinions]
          paragraph.opinions.each do |opinion|
            nb_opinions += 1
            opinion.update_status(get_products)
            opinion.accept! if opinion.to_review? and options[:force_to_review_ok]
          end
        end
        paragraph.update_status
      end
      review.update_status
      puts "review #{i} processed in #{'%2.5f' % (Time.now - t0)} s for #{nb_opinions} opinions"
    end
    true
  end


  def get_price_min_html(product) get_price_min_max_html(product, :min) end
  def get_price_min_max_html(product, mode = :minmax)
    price_min, price_max = Price.min_max(product.id)
    if price_min and price_max
      if mode == :minmax and price_min != price_max
        "$ #{'%.2f' % price_min} to $ #{'%.2f' % price_max}"
      else
        "$ #{'%.2f' % price_min}"
      end
    else
      "n/a"
    end
  end




  # this entry will update the whole xml directories/files
  def generate_xml
    domain_directory = "public/domains/#{idurl}"
    doc = XML::Document.new
    node_knowledge = super(doc)
    Root.write_xml_list(node_knowledge, features, 'sub_features')
    doc.save("#{domain_directory}/knowledge/knowledge.xml")

    Knowledge.write_children_xml(self, question_idurls, domain_directory, "Question")
    Knowledge.write_children_xml(self, product_idurls, domain_directory, "Product")
    Knowledge.write_children_xml(self, quizze_idurls, domain_directory, "Quizze")
  end

  def self.to_xml()
    doc = XML::Document.new
    doc.root = node_knowledges = XML::Node.new("knowledges")
    Knowledge.all.each { |knowledge| node_knowledges << knowledge.to_xml_bis }
    doc.to_s(:indent => true)    
  end

  def to_xml_bis
    node_knowledge = XML::Node.new("Knowledge")
    node_knowledge['idurl'] = idurl
    node_knowledge['label'] = label

    # products
    node_knowledge << node_products = XML::Node.new("products")
    products.each do |product|
      node_products << node_product = XML::Node.new(product.class.to_s)
      node_product['idurl'] = product.idurl
    end

    # questions
    node_knowledge << node_questions = XML::Node.new("questions")
    questions.each do |question|
      node_questions << node_question = XML::Node.new(question.class.to_s)
      node_question['idurl'] = question.idurl
    end

    # quizzes
    node_knowledge << node_quizzes = XML::Node.new("quizzes")
    quizzes.each do |quizze|
      node_quizzes << node_quizze = XML::Node.new(quizze.class.to_s)
      node_quizze['idurl'] = quizze.idurl
    end

    # features
    node_knowledge << node_features = XML::Node.new("features")
    features.each do |feature|
      node_features << node_feature = feature.generate_xml(node_features)
    end
    
    node_knowledge
  end


  def generate_product_template(product=nil)
    doc = XML::Document.new
    doc.root =  (top_node = XML::Node.new("Product"))
    top_node['label'] = product ? product.label : "Label..."
    features.each { |feature| feature.generate_product_template(top_node, 0, product)  }
    path = "public/domains/#{idurl}"
    if product
      path = "#{path}/products/#{product.idurl}"
      system("mv #{path}/product.xml #{path}/product_ph.xml")
      doc.save("#{path}/product.xml")
    else
      doc.save("#{path}/knowledge/product_template.xml")
    end
  end

  # cancel the recommendations generated by a previous answer
  def cancel_recommendations(question, last_answer, quizze_instance, products)
    raise "i don't get it..."
    propagate_recommendations(question, last_answer, quizze_instance.hash_pidurl_affinity, products, true)
  end

  # propagate the recommendations associated with the choices_ok
  # update hash_pidurl_affinity ( a hash table between a product-idurl and and a user affinity)
  def propagate_recommendations(question, answer, hash_pidurl_affinity, products, reverse_mode)
    puts "filtering not implemented yet" if question.is_filter
    question.delta_weight(answer).each do |product_idurl, weight|
      hash_pidurl_affinity[product_idurl].add(weight * (reverse_mode ? -1.0 : 1.0), question.weight)
    end
  end

  # return a new affinity list
  def trigger_recommendations(quizze_instance, question, products, choices_ok, simulation)
    choice_idurls_ok = choices_ok.collect(&:idurl)
    answer = quizze_instance.record_answer(self.idurl, question.idurl, choice_idurls_ok)
    hash_pidurl_affinity = quizze_instance.hash_pidurl_affinity
    hash_pidurl_affinity = hash_pidurl_affinity.inject({}) { |h, (pidurl, a)| h[pidurl] = a.clone } if simulation
    propagate_recommendations(question, answer, hash_pidurl_affinity, products, false)
    quizze_instance.cancel_answer(answer) if simulation
    hash_pidurl_affinity
  end

  def get_product_by_idurl(idurl)
    @hash_idurl_product ||= products.inject({}) { |h, p| ensure_unique(h, p) }
    @hash_idurl_product[idurl]
  end

  def get_question_by_idurl(idurl)
    @hash_idurl_question ||= questions.inject({}) { |h, q| ensure_unique(h, q) }
    @hash_idurl_question[idurl]
  end





  def clean_url(url, product)
    if url and (url.has_prefix("http") or url.has_prefix("/"))
      url
    else
      # local url
      "/domains/#{idurl}/products/#{product.idurl}/#{url}"
    end
  end

  def default_counter(reset_cache, keyname)
    if reset_cache or self.send(keyname).nil?
      self.send("#{keyname}=", yield)
    end
    self.send(keyname)
  end

  # ---------------------------------------------------------------------
  # Compute aggregation
  # ---------------------------------------------------------------------
  
  def compute_aggregation
    all_products = get_products

    all_products.each { |p| p.explanation_rating = {} }
    dimensions.each { |dimension| all_products.each { |product| product.set_value(dimension.idurl, nil); product.save } }

    compute_aggregation_recursive(dimension_root, all_products)

    # save main rating and explanations inside product object
    all_products.each { |product| product.overall_rating = product.get_value(dimension_root.idurl); product.save }

    self.update_attributes(:last_aggregation_timestamp => Time.now)

    # for each dimension... and usages
    # Dimension.all.concat(Usage.all).each
  end


  def compute_aggregation_recursive(dimension, all_products)
    dimension.children.each { |sub_dimension| compute_aggregation_recursive(sub_dimension, all_products) }
    compute_aggregation_bis(dimension, all_products)
  end

  # compute the aggregation for a given dimension (its sub-dimensions already computed)
  def compute_aggregation_bis(dimension_or_usage, all_products)
    dimension_or_usage.compute_aggregation(all_products).each do |product_id, rating_01|
      product = get_product_by_id(product_id)
        product.set_value(dimension_or_usage.idurl, rating_01)
        product.save
    end
    puts "aggregation computed for dimension #{dimension_or_usage.idurl}"
  end

  # differents kind of ranking of prodsucts
  def ranking_categories(ranking_threshold, dimension_idurl=nil)
    dimension = dimension_idurl ? get_dimension_by_idurl(dimension_idurl) : dimension_root
    raise "dimension_idurl=#{dimension_idurl}" unless dimension
    all_products = products.select { |p| dimension.confidence(p) > ranking_threshold }

    all_products.sort! do |p1, p2|
      p2.get_dimension_value(dimension.idurl) <=> p1.get_dimension_value(dimension.idurl)
    end

    ProductsByShortcut.shortcuts.inject([]) do |l, (shortcut, shortcut_label)|
      pf = ProductsByShortcut.new(:shortcut_selector => shortcut)
      sub_products = pf.compute_matching_product(all_products)
      l <<  [shortcut, shortcut_label, sub_products]
      l
    end
  end

  # ===================================================================================================
  private

  # ------------------------------------------------------------------------------------
  #  utilities to handle the specifications/dimensions hierarchical structure
  # and provide hash access by id and idurl
  # :all_roots => true, return a list of roots
  # :one_root => true, returns the unique root
  # :by_id => id, returns the object with id
  # :by_idurl => idurl, returns the object with idurl
  # :reset => true, recompute the cache
  def tree_manager(method_node, options)
    @tree_cache ||= {}
    if @tree_cache[method_node].nil? or options[:reset]
      # recompute all caches
      @tree_cache[method_node] = { :by_id => {}, :by_idurl => {}, :roots => [] }
      # compute hash by_id and by_idurl
      self.send(method_node).each do |node|
        node.children = []
        @tree_cache[method_node][:by_id][node.id] = node
        ensure_unique(@tree_cache[method_node][:by_idurl], node)
      end
      # compute hierarchical structure
      @tree_cache[method_node][:by_id].each do |nid, node|
        if node.parent_id
          node.parent = @tree_cache[method_node][:by_id][node.parent_id]
          node.parent.children << node
        else
          @tree_cache[method_node][:roots] << node
        end
      end

      # sort nodes, compute level and indexes
      tree_manager_bis(@tree_cache[method_node][:roots])

    end
    # return result
    if options[:by_id]
      options[:by_id] = BSON::ObjectID.from_string(options[:by_id]) unless options[:by_id].is_a?(BSON::ObjectID)
      @tree_cache[method_node][:by_id][options[:by_id]]
    elsif options[:by_idurl]
      @tree_cache[method_node][:by_idurl][options[:by_idurl]]
    elsif options[:all_roots]
      @tree_cache[method_node][:roots]
    elsif options[:one_root]
      @tree_cache[method_node][:roots].first
    else
      raise "error unknown options = #{options.inspect}"
    end
  end

  def tree_manager_bis(nodes, level=1, indexes=[])
    nodes.sort! { |n1, n2| n1.ranking_number <=> n2.ranking_number }
    nodes.each_with_index do |node, index|
      node.level = level
      node.indexes = (indexes.clone << index)
      tree_manager_bis(node.children, level + 1, node.indexes)
    end
  end

  # ------------------------------------------------------------------------------------
  #  utilities to handle the products/questions,... structure
  # and provide hash access by id and idurl
  # :all => true, return a list of all nodes
  # :by_id => id, returns the object with id
  # :by_idurl => idurl, returns the object with idurl
  # :reset => true, recompute the cache
  def list_manager(method_node, options)
    @list_cache ||= {}
    if @list_cache[method_node].nil? or options[:reset]
      # recompute all caches
      @list_cache[method_node] = { :by_id => {}, :by_idurl => {}, :all => [] }
      # compute hash by_id and by_idurl
      self.send(method_node).each do |node|
        @list_cache[method_node][:by_id][node.id] = node
        ensure_unique(@list_cache[method_node][:by_idurl], node)
        @list_cache[method_node][:all] << node
      end
      # sort nodes
      @list_cache[method_node][:all].sort! { |o1, o2| o1.label <=> o2.label }
    end
    # return result
    if options[:by_id]
      options[:by_id] = BSON::ObjectID.from_string(options[:by_id]) unless options[:by_id].is_a?(BSON::ObjectID)
      @list_cache[method_node][:by_id][options[:by_id]]
    elsif options[:by_idurl]
      @list_cache[method_node][:by_idurl][options[:by_idurl]]
    elsif options[:all]
      @list_cache[method_node][:all]
    else
      raise "error unknown options = #{options.inspect}"
    end
  end


  def ensure_unique(h, o)
    raise "OUPS more than one idurl=#{o.idurl}" if h[o.idurl]
    h[o.idurl] = o; h
  end

end
