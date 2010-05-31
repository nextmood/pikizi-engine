# describe a query resulting as a set of products

class ProductsQuery
  include MongoMapper::Document
  
  key :products_query_atoms, Array # of ProductsQueryAtom
  key :logical_operators, Array # of String "and", "or"   (ps.atoms.size == logical_operators.size - 1)

  # process attributes
  def self.process_attributes(knowledge, params)
    ps = self.new
    ps.products_query_atoms = ProductsQuery.get_attributes_with_prefix("ps_atom_", params).collect { |params_atom| ProductsQueryAtom.process_attributes(knowledge, params_atom) }
    ps.logical_operators = ProductsQuery.get_attributes_with_prefix("logical_operator_", params)
    # compute_product_matching_ids
    products_matching(knowledge)
    ps
  end

  def to_html
    s = products_query_atoms[0].label
    for i in 0 .. logical_operators.size - 1
      s << " #{logical_operators[i]} #{products_query_atoms[i+1].label}"
    end
    s
  end

  def process_products_matching_query
    products_matching_query  = products_query_atoms.first.products_matching_query
    for i in 0 .. logical_operators.size - 1
      products_matching_query << "#{logical_operators[i] == 'and' ? ' && ' : ' || '} #{products_query_atoms[i+1].products_matching_query}"
    end
    Product.all("$where" => "function() { return #{products_matching_query}; }").collect(&:label)
  end


  # upload javascript function to mongodb
  # return
  # db.system.js.save( { _id : "foo" , value : function( x , y ){ return x + y; } } );
  def self.upload_js
    function_js = {}
    function_js["ensure_array"] = "function(a) {
                                  if (!(a instanceof Array)) a = [a];
                                  return a;
                                 }"    
    function_js["has_value"] = "function(p, e) {
                                  p = ensure_array(p);
                                  for (var i = 0; i < p.length; i++) {
                                    if (p[i] == e) return true;
                                  };
                                  return false;
                                 }"
    function_js["has_any"] = "function(p, e) {
                                  p = ensure_array(p);
                                  e = ensure_array(e);
                                  for (var i = 0; i < e.length; i++) {
                                    if (has_value(p, e[i])) return true;
                                  };
                                  return false;
                                 }"
    function_js["has_all"] = "function(p, e) {
                                  p = ensure_array(p);
                                  e = ensure_array(e);
                                  for (var i = 0; i < e.length; i++) {
                                    if (!(has_value(p, e[i]))) return false;
                                  };
                                  return true;
                                 }"

    file_name = "pkz_mongo_init.js"
    File.open(file_name, "w+") do |aFile|
      function_js.each do |f_name, f_block|
        f_block = f_block.split(' ').collect(&:strip).join(' ')
        aFile.puts "db.system.js.save({_id : #{f_name.inspect}, value : #{f_block}});"
      end
    end
    # following line upload javascript functions to databse
    `/Applications/mongodb-osx-x86_64-1.2.2/bin/mongo pikizi_mongodb_development #{file_name}`
    true
  end

  #mongo pikizi_mongodb_development toto.js

  # db["products"].find({$where: "this._id == '4b892a6c43a76d7c3f0001a6'"}).length();
  # db["products"].find({$where: "has_any(this.similar_product_ids, ['4b892a6d43a76d7c3f0001b9'])"}).length();
  private
                       4

  # lookup all params starting with "ps_atom_" and  "logical_operator_"
  def self.get_attributes_with_prefix(prefix, params)
    selected_params = params.select { |k,v| k.has_prefix(prefix) }
    selected_params = selected_params.collect { |k,v| [Integer(k.remove_prefix(prefix)), v] }
    selected_params.sort! { |(k1,v1), (k2,v2)| k1 <=> k2 }
    selected_params.collect(&:last)
  end
  
end

class ProductsQueryAtom
  include MongoMapper::Document
  
  def self.process_attributes(knowledge, params)
    new_products_query_atom = Kernel.const_get(params[:products_query_atom_type]).new
    new_products_query_atom.process_attributes(knowledge, params)
    new_products_query_atom
  end

  # debug purpose...
  def process_products_matching_query
    puts "processing #{products_matching_query.inspect}"
    Product.all("$where" => "function() { return #{products_matching_query}; }").collect(&:label)
  end
  
end

# collect a set of products
# describe by a label in the glossary
class ProductsQueryFromProductLabel < ProductsQueryAtom
  key :product_id, BSON::ObjectID
  key :and_similar, Boolean
  belongs_to :product
  key :label, String

  def to_html() "#{product_id ? label : label.inspect }#{' and similar' if and_similar}" end

  def products_matching_query
    s = "(this._id == '#{product_id}')"
    s = "(#{s} || has_value(this.similar_product_ids, '#{product_id}'))" if and_similar
    s
  end

  def process_attributes(knowledge, params)
    self.label = params[:product_label]
    product = Product.first(:label => label, :knowledge_id => knowledge.id)
    self.product_id = (product ? product.id : nil)
    self.and_similar = true if params[:and_similar] and product
  end
end


class ProductsQueryFromSpecification < ProductsQueryAtom
  key :specification_tag_idurl, String
  key :subset_tag_idurls, Array
  key :is_exclusive, Boolean
  key :all_tags_mandatory, Boolean, :default => false # otehrwise at least one tag
  key :specification_label

  def to_html
    "#{specification_label}:(#{subset_tag_idurls.join(all_tags_mandatory ? ' and ' : ' or ')})"
  end

=begin
  Tests...
  mono tag (brand)
  ProductsQueryAtom.process_attributes(Knowledge.first, { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000001", :subset_tag_idurls => ["apple", "blackberry"]}).process_products_matching_query

  multi tags  (carrier_compatibility)
  ProductsQueryAtom.process_attributes(Knowledge.first, { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000003", :subset_tag_idurls => ["sprint", "att"]}).process_products_matching_query

=end

  def process_attributes(knowledge, params)
    specification = Specification.find(params[:specification_id])
    self.subset_tag_idurls = params[:subset_tag_idurls]
    raise "error specification class #{specification.class} not supported or subset_tag_idurls is empty" unless specification.is_a?(SpecificationTags) and subset_tag_idurls.size >= 1
    self.is_exclusive = specification.is_exclusive
    self.specification_tag_idurl = specification.idurl 
    self.specification_label = specification.label
    self.all_tags_mandatory = ((params[:all_tags_mandatory] and !specification.is_exclusive) ? true : false)
  end

  def products_matching_query
    subset_tag_idurls_js = subset_tag_idurls.collect { |tag_idurl| "'#{tag_idurl}'" }.join(', ')
    if is_exclusive
      "(has_value(this.hash_feature_idurl_value.#{specification_tag_idurl}), [#{subset_tag_idurls_js}])"      
    else
      "(has_#{all_tags_mandatory ? 'all' : 'any'}(this.hash_feature_idurl_value.#{specification_tag_idurl}, [#{subset_tag_idurls_js}]))"
    end

  end

end

class ProductsQueryFromShortcut < ProductsQueryAtom
  key :shortcut_selector, String

  def process_attributes(knowledge, params)
    self.shortcut_selector = params[:shortcut_selector]
  end

  def to_html
    shortcut_datas = ProductsQueryFromShortcut.list_shortcuts[shortcut_selector]
    shortcut_datas ? shortcut_datas[:label] : shortcut_selector.inspect.to_s
  end

  # this is where you extend new shortcut selector
  # this should be in the glossary? ... this in domain dependant
  def self.list_shortcuts() {

    "all_products" => {
      :label => "All products",
      :filter_block => Proc.new {|product| true }
    },

          
    "all_android" =>  {
      :label => "All android",
      :filter_block => Proc.new { |product|
        os = product.get_value("operating_system")
        ["android_15", "android_16", "android_2", "android_21", "android"].include?(os.first) if os
      }
    },

    "all_windows" =>  {
      :label => "All windows",
      :filter_block => Proc.new { |product|
        os = product.get_value("operating_system")
        os.first.downcase.include?("window") if os
      }
    },

    "all_blackberry" =>  {
      :label => "All blackberry",
      :filter_block => Proc.new { |product|
        os = product.get_value("operating_system")
        os.first.downcase.include?("blackberry") if os
      }
    },

    "all_feature_phones" =>  {
      :label => "All feature phones",
      :filter_block => Proc.new {|product| true }
    },

    "all_smartphones" =>  {
      :label => "All smart phones",
      :filter_block => Proc.new { |product|
        category = product.get_value("phone_category")
        category.first.downcase.include?("smartphone") if category
      } 
    }

  }
  end




end