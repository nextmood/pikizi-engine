class ProductsFilter
  include MongoMapper::Document
  key :_type, String # class management
  key :opinion_id, Mongo::ObjectID
  key :products_selector_dom_name, String
  key :display_as, String
  key :short_label, String
  key :preceding_operator, String, :default => "and"

  def generate_matching_products(all_products) all_products.select { |product| concern?(product) } end
  
end

class ProductByLabel < ProductsFilter
  key :product_id, Mongo::ObjectID
  key :and_similar, Boolean, :default => true
  key :similar_product_ids, Array, :default => []

  def update_labels(p=nil)
    p ||= Product.find(product_id)
    self.update_attributes(:display_as => p ? "#{p.label}#{' and similar(s)' if and_similar}" : "???",
                           :short_label => p ? p.idurl : "???",
                           :similar_product_ids => p.similar_product_ids)
  end

  def concern?(product) similar_product_ids.include?(product.id) or product_id == product.id end

end

class ProductsBySpec < ProductsFilter
  key :mode_selection_tag, String, :default => "or"
  key :specification_id, Mongo::ObjectID
  key :specification_idurl, String, :default => nil
  key :expressions, Array, :default =>[] # list of filter for the spec   if a or/and expression

  def update_labels(s = nil)
    s ||= Specification.find(specification_id)
    tail = expressions.join(" #{mode_selection_tag} ")
    self.update_attributes(:display_as => "#{s.label} = #{tail}", :short_label => "#{s.idurl} = #{tail}")
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

  def self.shortcuts() { "all_products" => "all products",
                         "all_smartphones" => "all smartphones",
                         "all_camera_phones" => "all camera phones",
                         "all_android" => "all android" } end

  def update_labels
    self.update_attributes(:display_as => ProductsByShortcut.shortcuts[shortcut_selector], :short_label => shortcut_selector)
  end

  def concern?(product)
    case shortcut_selector
      when "all_products" then true
      when "all_smartphones" then ["smartphone"].include?(product.get_value("phone_category"))
      when "all_camera_phones" then ["camera_phone"].include?(product.get_value("phone_category"))
      when "all_android" then ["android_15", "android_16", "android_2", "android_21", "android"].include?(product.get_value("operating_system"))
      else
        raise "no shortcut selector for #{shortcut_selector}"
    end
  end

end

