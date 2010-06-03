# describe a query resulting as a set of products

class ProductsQuery
  include MongoMapper::Document

  many :products_query_atoms  # embedded document
  key :logical_operators, Array # of String "and", "or"   (products_query_atoms - 1 == logical_operators.size)
  key :knowledge_id
  key :name, String
  
  # create a new query
  def self.create_debug(name, knowledge_id, params)
    process_attributes(name, params.inject({}) { |h, (k,v)| h["#{name}_#{k}"] = v; h }.merge(:knowledge_id => knowledge_id))
  end

  # process attributes
  def self.process_attributes(name, params)
    pq = ProductsQuery.new
    pq.knowledge_id = params[:knowledge_id]
    pq.name = name 
    pq.products_query_atoms = ProductsQuery.get_attributes_with_prefix("#{name}_products_query_atom_", params).collect { |params_atom| ProductsQueryAtom.process_attributes(params_atom.merge(:knowledge_id => pq.knowledge_id, :name => name)) }
    pq.logical_operators = ProductsQuery.get_attributes_with_prefix("#{name}_products_query_logical_", params)
    pq
  end

  def to_html
    s = products_query_atoms[0].to_html
    for i in 0 .. logical_operators.size - 1
      s << " <b>#{logical_operators[i]}</b> #{products_query_atoms[i+1].to_html}"
    end
    s
  end

  def process_products_matching_query
    Product.all("$where" => "function() { return #{products_matching_query}; }").collect(&:label)
  end

  def products_matching_query
    q  = products_query_atoms.first.products_matching_query
    for i in 0 .. logical_operators.size - 1
      q << "#{logical_operators[i] == 'and' ? ' && ' : ' || '} #{products_query_atoms[i+1].products_matching_query}"
    end
    q
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
  # sort them by the suffix
  # collect all values of these ordered parameters
  def self.get_attributes_with_prefix(prefix, params)
    selected_params = params.select { |k,v|  k.is_a?(String) ? k.has_prefix(prefix) : ( puts "unknown=#{k.inspect}" ;nil) }
    selected_params = selected_params.collect { |k,v| [Integer(k.remove_prefix(prefix)), v] }
    selected_params.sort! { |(k1,v1), (k2,v2)| k1 <=> k2 }
    selected_params.collect(&:last)
  end
  
end

class ProductsQueryAtom
  include MongoMapper::EmbeddedDocument

  key :name, String
  key :rank_index, Integer, :default => 0
  key :knowledge_id

  def self.process_attributes(params)
    new_products_query_atom = Kernel.const_get(params[:products_query_atom_type]).new
    new_products_query_atom.knowledge_id = params[:knowledge_id]
    new_products_query_atom.name = params[:name]
    new_products_query_atom.rank_index = Integer(params[:index] || 99)
    new_products_query_atom.process_attributes(params)
    new_products_query_atom
  end

  # debug purpose...
  def process_products_matching_query
    if q = products_matching_query
      Product.all("$where" => "function() { return #{q}; }")
    else
      []
    end
  end
  
end

# collect a set of products
# describe by a label in the glossary
class ProductsQueryFromProductLabel < ProductsQueryAtom
  key :product_id, BSON::ObjectID
  key :extension, String, :default => "none"
  def has_extension() extension != "none" end
  belongs_to :product
  key :product_label, String

  def to_html() "#{product_id ? product_label : ('<span style="color:red;">' << product_label << '</span>') }#{(' and ' << extension << ' items') if has_extension }" end

  def products_matching_query
    if product_id
      s = "(this._id == '#{product_id}')"
      s = "(#{s} || has_value(this.#{extension}_product_ids, '#{product_id}'))" if has_extension
      s
    end
  end

  def process_attributes(params)
    self.product_label = params[:product_label]
    product = Product.first(:label => product_label, :knowledge_id => params[:knowledge_id])
    self.product_id = (product ? product.id : nil)
    self.extension = params[:extension]
  end
end


class ProductsQueryFromSpecification < ProductsQueryAtom
  key :specification_tag_idurl, String
  def specification() 
    x = Specification.first(:knowledge_id => knowledge_id, :idurl => specification_tag_idurl)
    puts "looking for #{specification_tag_idurl} #{knowledge_id} -> #{x.inspect}"
x    
  end
  key :subset_tag_idurls, Array
  key :is_exclusive, Boolean
  key :mode_selection_tag, String, :default => "any" 
  key :specification_label

  def to_html
    "#{specification_label}:(#{subset_tag_idurls.join(mode_selection_tag == 'all' ? ' and ' : ' or ')})"
  end


  def process_attributes(params)
    specification = Specification.find(params[:specification_id])
    self.subset_tag_idurls = params[:subset_tag_idurls]
    raise "error specification class #{specification.class} not supported or subset_tag_idurls is empty" unless specification.is_a?(SpecificationTags) and subset_tag_idurls.size >= 1
    self.is_exclusive = specification.is_exclusive
    self.specification_tag_idurl = specification.idurl 
    self.specification_label = specification.label
    self.mode_selection_tag = ((params[:mode_selection_tag] and !specification.is_exclusive) ? params[:mode_selection_tag] : "any")
  end

  def products_matching_query
    subset_tag_idurls_js = subset_tag_idurls.collect { |tag_idurl| "'#{tag_idurl}'" }.join(', ')
    if is_exclusive
      "(has_value([#{subset_tag_idurls_js}], this.hash_feature_idurl_value.#{specification_tag_idurl}))"      
    else
      "(has_#{mode_selection_tag}(this.hash_feature_idurl_value.#{specification_tag_idurl}, [#{subset_tag_idurls_js}]))"
    end

  end

end

class ProductsQueryFromShortcut < ProductsQueryAtom
  key :shortcut_selector, String

  def process_attributes(params)
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