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
end

class ProductsBySpec < ProductsFilter
  key :mode_selection_tag, String, :default => "or"
  key :specification_id, Mongo::ObjectID
  key :expressions, Array, :default =>[] # list of filter for the spec   if a or/and expression
end


class ProductsByShortcut < ProductsFilter
  key :shortcut_selector, String
end

