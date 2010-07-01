class ProductsFilter
  include MongoMapper::Document
  key :_type, String # class management
  key :opinion_id, BSON::ObjectID
  key :products_selector_dom_name, String
  key :display_as, String
  key :short_label, String
  key :preceding_operator, String, :default => "or"

  # return a  list of products among all products matching this products_filter
  def compute_matching_product(among_products) among_products.select { |product| concern?(product, among_products) } end
  def compute_matching_product_ids(among_products) compute_matching_product(among_products).collect(&:id) end

  def process_attributes(knowledge, products_selector_dom_name, opinion, params)
    self.preceding_operator = params["preceding_operator"]
    self.opinion_id = opinion.id
    self.products_selector_dom_name = products_selector_dom_name
  end

end

class ProductsFilterAnonymous < ProductsFilter

  key :extract, String
  def label() extract end
  def update_labels
    self.display_as = ProductsFilterAnonymous.build_label(extract)
    self.short_label = extract
    self
  end
  def update_labels_debug() update_labels end
  def concern?(a_product, among_products) false end

  def self.code_constructor(extract) "ProductsFilterAnonymous.new(:extract => \"#{extract}\").update_labels()"  end

  # mutate this anoymous to a real ProductFilter
  def mutate(new_constructor)
    new_object = eval(new_constructor)
    new_object.id = id
    update_labels_debug
    new_object.save
    new_object
  end

  def self.build_label(resolve_string) "<span color='red'>#{resolve_string}</span>" end

end

class ProductByLabel < ProductsFilter
  key :product_id, BSON::ObjectID
  belongs_to :product

  key :and_similar, Boolean, :default => true


  def self.code_constructor(product, and_similar) "p=Product.find('#{product.id}'); ProductByLabel.new(:product_id => p.id, :and_similar => #{and_similar}).update_labels(p)"  end


  def process_attributes(knowledge, products_selector_dom_name, opinion, params)
    super(knowledge, products_selector_dom_name, opinion, params)
    product_label = params["label"].strip
    unless existing_product = Product.first(:label => product_label)
      # creating a new product
      existing_product = Product.create(:idurl => product_label.downcase.gsub(' ','_'), :label => product_label, :knowledge_id => knowledge.id)
    end
    self.product_id = existing_product.id
    self.and_similar = (params["and_similar"] == "1")
    update_labels(existing_product)
  end

  def label() product_id ? product.label : "" end
  
  def update_labels(p)
    self.display_as = (p ? "#{p.label}#{' and similar(s)' if and_similar}" : "???")
    self.short_label = (p ? "#{p.idurl}#{ '_and_similars' if and_similar}" : "???")
    self
  end
  def update_labels_debug() update_labels(product) end

  def concern?(a_product, among_products) product_and_similar_ids(among_products).include?(a_product.id) end

  def product_and_similar_ids(among_products)
    unless @product_and_similar_ids_cache
      @product_and_similar_ids_cache = [product_id]
      if and_similar
        if the_product = among_products.detect { |p| p.id == product_id }
          @product_and_similar_ids_cache.concat(the_product.similar_product_ids)
        else
          # puts "OUPS product #{product.id}  #{product.label} [#{product.release_date.inspect}] use ahead of time in opinion #{opinion_id} #{Opinion.find(opinion_id).written_at}"
        end
      end
    end
    @product_and_similar_ids_cache
  end

end

class ProductsBySpec < ProductsFilter
  key :mode_selection_tag, String, :default => "all"  # "all" or "any"
  key :specification_id, BSON::ObjectID
  belongs_to :specification
  key :specification_idurl, String, :default => nil
  key :expressions, Array, :default =>[] # list of tags to match

  def process_attributes(knowledge, products_selector_dom_name, opinion, params)
    super(knowledge, products_selector_dom_name, opinion, params)
    self.mode_selection_tag = params["mode_selection_tag"]
    s = Specification.find(params["specification_id"])
    self.specification_id = s.id
    self.specification_idurl = s.idurl
    self.expressions = (params["expressions"] || []).select { |tag_idurl| tag_idurl.size > 0 }
    update_labels(s)
  end

  def update_labels(s)
    tail = expressions.join(', ')
    self.display_as = (s ? "#{s.label} =#{mode_selection_tag} [#{tail}]" : "???")
    self.short_label = (s ? "#{s.idurl} =#{mode_selection_tag} [#{tail}]" : "???")
    self
  end
  def update_labels_debug() update_labels(specification).specification_idurl = specification.idurl; self end

  def concern?(product, among_products)
    values = product.get_value(specification_idurl)
    case mode_selection_tag
      when "all" then values and values.all? { |value| expressions.include?(value) }
      when "any" then values and values.any? { |value| expressions.include?(value) }
    end
  end

end


class ProductsByShortcut < ProductsFilter
  key :shortcut_selector, String

  def self.shortcuts() [ ["all_products", "all products"],
                         ["all_android", "all Android phones"],
                         ["all_windows", "all Windows phones"],
                         ["all_blackberry", "all Blackberry phones"],
                         ["all_feature_phones", "all feature-phones"],
                         ["all_smartphones", "all smartphones"],
                          ] end

  def process_attributes(knowledge, products_selector_dom_name, opinion, params)
    super(knowledge, products_selector_dom_name, opinion, params)
    self.shortcut_selector = params["shortcut_selector"]
    update_labels
  end

  def update_labels
    self.display_as = ProductsByShortcut.shortcuts.detect {|s| s.first == shortcut_selector }.last
    self.short_label = shortcut_selector
    self
  end
  def update_labels_debug() update_labels() end

  def self.code_constructor(shortcut_idurl) "ProductsByShortcut.new(:shortcut_selector => '#{shortcut_idurl}').update_labels()" end

  def concern?(product, among_products)
    case shortcut_selector
      when "all_products" then true
      when "all_android"
        os = product.get_value("operating_system")
        ["android_15", "android_16", "android_2", "android_21", "android"].include?(os.first) if os
      when "all_windows"
        os = product.get_value("operating_system")
        os.first.downcase.include?("window") if os
      when "all_blackberry"
        os = product.get_value("operating_system")
        os.first.downcase.include?("blackberry") if os
      when "all_feature_phones" then true
      when "all_smartphones"
        category = product.get_value("phone_category")
        category.first.downcase.include?("smartphone") if category
      else
        raise "no shortcut selector for #{shortcut_selector.inspect}.........."
    end
  end


end

