class ProductsFilter
  include MongoMapper::Document
  key :_type, String # class management
  key :opinion_id, Mongo::ObjectID
  key :products_selector_dom_name, String
  key :display_as, String
  key :short_label, String
  key :preceding_operator, String, :default => "and"
end

class ProductByLabel < ProductsFilter
  key :product_id, Mongo::ObjectID

  def generate_matching_products(all_products) all_products.select { |p| p.id == product_id } end

  def compute_labels
    p = Product.find(product_id)
    self.display_as = p ? p.label : "???"
    self.short_label = p ? p.idurl : "???"
  end

  def concern?(product) product.id ==  product_id end

end

class ProductsBySpec < ProductsFilter
  key :mode_selection_tag, String, :default => "or"
  key :specification_id, Mongo::ObjectID
  key :specification_idurl, String, :default => nil
  key :expressions, Array, :default =>[] # list of filter for the spec   if a or/and expression

  def generate_matching_products(all_products)
    all_products.select do |product|
      values = product.get_value(specification_idurl)
      case mode_selection_tag
        when "or" then values and values.any? { |value| expressions.include?(value) }
        when "and" then values and values.all? { |value| expressions.include?(value) }
      end
    end
  end

  def compute_labels
    s = Specification.find(specification_id)
    self.display_as = "#{s.label} = " << expressions.join(" #{mode_selection_tag} ")
    self.short_label = "#{s.idurl} = " << expressions.join(" #{mode_selection_tag} ")
  end

  def concern?(product)
    values = product.get_value(specification_idurl)
    case mode_selection_tag
      when "or" then values and values.any? { |value| expressions.include?(value) }
      when "and" then values and values.all? { |value| expressions.include?(value) }
    end
  end

end


class ProductsByShortcut < ProductsFilter
  key :shortcut_selector, String

  def generate_matching_products(all_products)
    case shortcut_selector
      when "all_products" then all_products
      else
        raise "no shortcut selector for #{shortcut_selector}"
    end
  end

  def compute_labels
    self.display_as = shortcut_selector
    self.short_label = shortcut_selector
  end

  def concern?(product) shortcut_selector ==  "all_products" end

end

