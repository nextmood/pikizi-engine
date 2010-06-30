# describe a query resulting as a set of products
require 'htmlentities'

class ProductsQuery
  include MongoMapper::Document

  many :products_query_atoms  # embedded document
  key :knowledge_id, BSON::ObjectID
  key :name, String
  
  # create a new query
  # query_atoms_and_logical -> a list of QueryAtom , logical_operator, QueryAtom, etc...
  
  def self.birth(name, knowledge_id, *query_atoms_and_logical)
    raise "error should be odd #{query_atoms_and_logical.size}" unless query_atoms_and_logical.size.odd?

    pq = ProductsQuery.new(:name => name, :knowledge_id => knowledge_id, :products_query_atoms => [])

    for i in 0 .. (query_atoms_and_logical.size-1)/2
      logical_operator = nil
      if i > 0
        logical_operator = query_atoms_and_logical[i * 2 - 1].downcase.strip
        raise "error #{logical_operator.inspect}" unless ["and", "or"].include?(logical_operator)
      end
      atom = query_atoms_and_logical[i * 2]
      atom.knowledge_id = knowledge_id
      atom.rank_index = i
      atom.preceding_operator = logical_operator
      atom.post_processing
      pq.products_query_atoms << atom
    end

    pq
  end

  # process attributes
  # this method is called when processing a form
  def self.process_attributes(name, knowledge, params)
    dom_prefix = "atom"
    params_query = params.collect { |k,v| raise "error #{k} is not an atom" unless k.has_prefix(dom_prefix); [Integer(k.remove_prefix(dom_prefix)), v] }
    # sort by index number for atoms
    params_query = params_query.sort { |(ri1, pa1), (ri2, pa2)|  ri1 <=> ri2 }.collect(&:last)
    params_query.each_with_index { |params_atom, new_rank_index| params_atom.merge!( :rank_index => new_rank_index, :knowledge_id => knowledge.id, :name => name ) }

    # params_query is an ordered list of hash like
    # {"products_query_atom_type"=>"ProductsQueryFromProductLabel", "extension"=>"similar", "preceding_operator"=>"or", "rank_index"=>"1", "product_label"=>"Blackberry Bold (T-Mobile)"}
    # or {"products_query_atom_type"=>"ProductsQueryFromSpecification", "mode_selection_tag"=>"all", "rank_index"=>"0", "specification_idurl"=>"carriers", "subset_tag_idurls"=>["att", "sprint"]}}
    
    pq = ProductsQuery.new
    pq.knowledge_id = knowledge.id
    pq.name = name

    pq.products_query_atoms = params_query.collect { |params_atom| ProductsQueryAtom.process_attributes(params_atom) }

    pq
  end

  def to_html
    products_query_atoms.collect(&:to_html).join
  end

  # execute the Query, returns a list of products
  def execute_query() ProductsQuery.execute_query(products_matching_query) end

  def self.execute_query(query)
    query = query.gsub(" or "," || ")
    query.gsub!(" and "," && ")
    begin
      Product.all("$where" => "function() { return #{query}; }", :order => "idurl asc")
    rescue Exception => e
      puts "warning error while query=#{query.inspect} #{e.message}"
      e.backtrace.each { |m| puts "     #{m}"}
      []
    end
  end

  # build the query sum of atom query
  def products_matching_query() products_query_atoms.collect(&:products_matching_query).join end
    
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
    #`/Applications/mongodb-osx-i386-1.2.3/bin/mongo pikizi_mongodb_development #{file_name}`
    `/Applications/mongodb-osx-x86_64-1.2.2/bin/mongo pikizi_mongodb_development #{file_name}`
    true
  end

  #mongo pikizi_mongodb_development toto.js

  # db["products"].find({$where: "this._id == '4b892a6c43a76d7c3f0001a6'"}).length();
  # db["products"].find({$where: "has_any(this.similar_product_ids, ['4b892a6d43a76d7c3f0001b9'])"}).length();
  private

  # lookup all params starting with a given prefix
  # sort them by the suffix (that should be an integer!)
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

  key :rank_index, Integer, :default => 0
  key :preceding_operator, String, :default => nil # "and", "or"   
  key :knowledge_id, BSON::ObjectID

  def self.process_attributes(params)
    new_products_query_atom = Kernel.const_get(params[:products_query_atom_type]).new
    knowledge_id = params[:knowledge_id]
    knowledge_id = BSON::ObjectID.from_string(knowledge_id) if knowledge_id.is_a?(String)
    new_products_query_atom.knowledge_id = knowledge_id
    new_products_query_atom.rank_index = Integer(params[:rank_index] || Time.now.to_i)
    new_products_query_atom.preceding_operator = (new_products_query_atom.rank_index > 0 ? params[:preceding_operator] : nil)
    new_products_query_atom.process_attributes(params)
    new_products_query_atom
  end


  def products_matching_query
    #(preceding_operator == 'and' ? ' && ' : ' || ') if preceding_operator
    " #{preceding_operator} " if preceding_operator    
  end

  # debug purpose...
  def process_products_matching_query
    if q = products_matching_query
      Product.all("$where" => "function() { return #{q}; }")
    else
      []
    end
  end

  def products_query_atom_type() self.class.to_s end

  def to_html() preceding_operator ? " #{preceding_operator} " : "" end

end

# collect a set of products
# describe by a label in the glossary
class ProductsQueryFromProductLabel < ProductsQueryAtom
  key :product_id, BSON::ObjectID
  key :extension, String, :default => "none"   # "similar", "next", "previous", "none"
  def has_extension() extension != "none" end
  belongs_to :product
  key :product_label, String

  def to_html
    product_label_html = product_id ? product_label : "<span style=\"color:red;\">#{product_label}</span>"
    suffix = has_extension ? " and #{extension} items" : ""
    "#{super}#{product_label_html}#{suffix}"
  end

  def products_matching_query
    if product_id
      s = "(this._id == '#{product_id}')"
      s = "(#{s} or has_value(this.#{extension}_product_ids, '#{product_id}'))" if has_extension
      "#{super}#{s}"
    end
  end

  def process_attributes(params)
    self.product_label = params[:product_label]
    product = Product.first(:label => product_label, :knowledge_id => params[:knowledge_id])
    self.extension = params[:extension]
    post_processing
  end

  def post_processing
    p = product = Product.first(:label => product_label, :knowledge_id => knowledge_id)
    self.product_id = (product ? product.id : nil)
    self
  end
end


class ProductsQueryFromSpecification < ProductsQueryAtom

  key :specification_idurl, String
  def specification()
    if specification_idurl and specification_idurl.size > 0
      @specification ||= Specification.first(:knowledge_id => knowledge_id, :idurl => specification_idurl)
      raise "error specification_idurl=#{specification_idurl} knowledge_id=#{knowledge_id} doens'nt exist" unless @specification
      @specification
    end
  end

  key :subset_tag_idurls, Array
  key :is_exclusive, Boolean
  key :mode_selection_tag, String, :default => "any" 
  key :specification_label

  def to_html
    "#{super}#{specification_label}:(#{subset_tag_idurls.join(mode_selection_tag == 'all' ? ' and ' : ' or ')})"
  end


  def process_attributes(params)
    self.specification_idurl = params[:specification_idurl]
    self.subset_tag_idurls = params[:subset_tag_idurls]
    self.mode_selection_tag = params[:mode_selection_tag]
    post_processing
  end

  def post_processing
    if specification.is_a?(SpecificationTags)
      self.specification_label = specification.label
      self.is_exclusive = specification.is_exclusive
      self.mode_selection_tag = "any" if is_exclusive
    end
    self
  end

  def products_matching_query
    subset_tag_idurls_js = subset_tag_idurls.collect { |tag_idurl| "'#{tag_idurl}'" }.join(', ')
    s = if is_exclusive
      "(has_value([#{subset_tag_idurls_js}], this.hash_feature_idurl_value.#{specification_idurl}))"
    else
      "(has_#{mode_selection_tag}(this.hash_feature_idurl_value.#{specification_idurl}, [#{subset_tag_idurls_js}]))"
    end
    "#{super}#{s}"
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