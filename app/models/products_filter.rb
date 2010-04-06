class ProductsFilter
  include MongoMapper::Document
  key :_type, String # class management
  key :opinion_id, Mongo::ObjectID
  key :products_selector_dom_name, String
  key :display_as, String
  key :preceding_operator, String, :default => "and"
end

class ProductByLabel < ProductsFilter
  key :product_id, Mongo::ObjectID

  def generate_pids(all_products) [product_id] end
  
end

class ProductsBySpec < ProductsFilter
  key :mode_selection_tag, String, :default => "or"
  key :specification_id, Mongo::ObjectID
  key :expressions, Array, :default =>[] # list of filter for the spec   if a or/and expression

  def generate_pids(all_products)
    specification_idurl = Specification.find(specification_id).idurl
    all_products.select do |product|
      values = product.get_value(specification_idurl)
      case mode_selection_tag
        when "or" then values and values.any? { |value| expressions.include?(value) }
        when "and" then values and values.all? { |value| expressions.include?(value) }
      end
    end.collect(&:id) 
  end

end


class ProductsByShortcut < ProductsFilter
  key :shortcut_selector, String

  def generate_pids(all_products)
    case shortcut_selector
      when "all_products" then all_products.collect(&:id)
      else
        raise "no shortcut selector for #{shortcut_selector}"
    end
  end
  
end

