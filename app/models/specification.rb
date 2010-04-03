require 'mongo_mapper'
require 'text'

# describe a Specification of the product
# this is a hierarchy mechanism
# see http://railstips.org/blog/archives/2010/02/21/mongomapper-07-identity-map/
class Specification

  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap

  key :idurl, String # unique url
  key :label, String
  key :is_optional, Boolean, :default => false
  key :display_flag, Boolean, :default => true
  key :_type, String # class management
  

  # knowledge
  key :knowledge_id
  belongs_to :knowledge

  
  # nested structure
  key :parent_id # a Specification object
  belongs_to :parent, :class_name => "Specification"
  # return all children
  def children() @children ||= Specification.all(:knowledge_id => knowledge_id, :parent_id => id) end
  def destroy() children.each(&:destroy); super() end #recursive destroy


  timestamps!

  def is_valid_value?(value) false end

  def is_root?() parent.nil? end

  def has_sub_features() features.size > 0 end

  def label_full() is_root? ? label : "#{parent.label_full}/#{label}" end

  def label_select_tag(rec=nil, full = nil)
    if rec
      is_root? ? "" : "#{full ? label << ':' : '...'}#{parent.label_select_tag(true, full)}"
    else
      "#{label_select_tag(true, full)}#{label}"
    end
  end

  def self.most_common() @@most_common ||= Specification.first(:idurl => "brand"); end
  

  def self.initialize_from_xml(xml_node)
    feature = super(xml_node)
    feature.is_optional = xml_node['is_optional']
    feature.display_flag = xml_node['no-spec'] ? true : false
    feature.read_xml_list(xml_node, "Specification", :container_tag => 'sub_features')
    feature
  end

  def generate_xml(top_node)
    node_feature = super(top_node)
    node_feature['is_optional'] = "true" if is_optional
    node_feature['no-spec'] = "true" if display_flag
    Root.write_xml_list(node_feature, features, 'sub_features')
    node_feature
  end

  def generate_product_template(top_node, depth, product)
    tag_name = self.class.to_s

    if tag_name == "SpecificationHeader"
      tabulation = "    " * (depth + 1)
      top_node << XML::Node.new_comment("#{tabulation}BEGIN #{label} ")
      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
      top_node << XML::Node.new_comment("#{tabulation}END #{label} ")
    elsif tag_name == "SpecificationRating"
      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
    else
      tabulation = "    " * depth
      #top_node << XML::Node.new_comment("#{tabulation}#{tag_name} #{label} ")
      top_node << (xml_node = XML::Node.new("Value"))
      xml_node['idurl'] = idurl
      if product and value = product.get_value(idurl)
        xml_node << value2xml(value)
      end
      xml_node << XML::Node.new_comment("#{tabulation}#{product_template_comment()} ")

      features.each { |sub_feature| sub_feature.generate_product_template(top_node, depth + 1, product) } if features.size > 0
    end

    top_node
  end
  def product_template_comment() raise "no comment for #{self.class}  " end

  # ---------------------------------------------------------------------
  # to display the matrix
  def get_value_html(product) get_value(product) end

  # this is included in a form
  def get_value_edit_html(product)
    "<div class=\"field\">
        <input type='text' name='feature_#{idurl}' value='#{get_value(product) || ""}' />
     </div>"
  end

  def get_feature_html() "<span title=\"feature #{self.class} idurl=#{idurl} level=#{level}\" >#{label}</span>#{specification_html_suffix}" end
  def specification_html_suffix()
    "<span style=\"margin-left:5px;\" title=\"rating feature\" >*</span>" unless is_optional
  end
  # this is included in a form
  def get_feature_edit_html()
    "<div class=\"field\" title=\"edit feature #{self.class}\">
        <div style='font-weight:normal; font-size:90%;'>#{self.class} : #{idurl}</div>
        <div>mandatory<input type='checkbox' #{'checked' unless is_optional}/></div>
        <div><span>label<span><input type='text' value='#{label}' /></div>
     <div>"
  end

  # convert value to string (and reverse for dumping data product's feature value)
  def xml2value(content_string) content_string.strip end
  def value2xml(value) value.to_s end

  def color_from_status(product)
    if is_relevant(product) == false
      "gray"
    elsif get_value(product)
      "lightblue"
    else
      is_optional ? "white" : "red"
    end
  end

  # this is related to feature condition
  def is_relevant(product)
    if is_a?(SpecificationCondition)
      (value = get_value(product)).nil? or value
    else
      parent ? parent.is_relevant(product) : true
    end
  end

  # this is related to display the specification
  def should_display?(product) !display_flag and (parent ? parent.should_display?(product) : true) end



  # the depth level of a feature
  def level() parent.nil? ? 1 : 1 + parent.level() end



  # ---------------------------------------------------------------------

  def each_specification(&block)
    block.call(self)
    specifications.each do |sub_specification|
      raise "specification= #{self.inspect}" if sub_specification.is_a?(Knowledge)
      sub_specification.each_specification(&block)
    end
    nil
  end


  # return the  SpecificationValue(s) for a product, nil if no value (==empty)
  def get_value(product) product.get_value(idurl) end
  def get_value_01(product) raise "error" end

 # define the distance between  2 products for this specification
  def distance(product1, product2)
    begin
      distance_metric(product1, product2)
    rescue
      "ERR"
    end
  end

  def distance_metric(product1, product2) "Undef #{get_value(product1).inspect}" end

#  def distance_graph(products)
#    g = GraphViz.new( :G, :type => :graph, :use => :dot, :path => "/usr/local/bin/" )
#
#    # adding nodes....
#    products.each { |p| g.add_node(p.idurl) }
#
#    # adding distance
#    products.each do |p1|
#      products.each do |p2|
#        if p1.idurl > p2.idurl
#          g.add_edge(g.get_node(p1.idurl), g.get_node(p2.idurl), :len => distance(p1, p2))
#        end
#      end
#    end
#    # Generate output image
#    g.output( :png => "/public/images/graphviz/distance.png" )
#  end

  #mode is either :comparator or :related
  def is_compatible_grammar(mode) false end


  def idurl_h()
    parent ? "#{parent.idurl_h}/#{idurl}" : idurl
  end


end


# =======================================================================================
# Describe a hierarchy of specifications
# =======================================================================================





# A tag is just a key and a label + backgrounds, i.e a root object
class Tag < Root
  include MongoMapper::EmbeddedDocument

  key :idurl, String # unique url
  key :label, String # text

end

# define a list of tags (exclusive or multiple)
# value is a list of tags ok
class SpecificationTags < Specification

  key :is_exclusive, Boolean

  many :tags

  def self.initialize_from_xml(xml_node)
    specification_tags = super(xml_node)
    specification_tags.is_exclusive = (xml_node['is_exclusive'] == "true" ? true : false)
    specification_tags.read_xml_list(xml_node, "Tag", :container_tag => 'tags')
    specification_tags
  end

  def generate_xml(top_node)
    node_specification_tag = super(top_node)
    node_specification_tag['is_exclusive'] = is_exclusive.to_s
    Root.write_xml_list(node_specification_tag, tags, 'tags')
    node_specification_tag
  end

  def product_template_comment() "#{is_exclusive ? 'ONE tag' : 'MANY tags'} among: #{tags.collect(&:idurl).join('  ')}" end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array of tag.idurl

  # value 0 for 0 tags selected
  # value 1 for all tags selected
  # the order is also taken into acount
  def get_value_01(product)
    Root.rule3(get_value(product).size.to_f, 0.0, tags.size.to_f)
  end

  def get_value_html(product)
    if tag_idurls_ok = get_value(product)
      tags.select { |t| tag_idurls_ok.include?(t.idurl) }.collect {|t| "#{t.label}" }.join(', ')
    end

  end

  def lookup_tag_by_idurl(tag_idurl) tags.detect { |t| t.idurl == tag_idurl } end
  
  # this is included in a form
  def get_value_edit_html(product)
    type_button = is_exclusive ? 'radio' : 'checkbox'
    tag_idurls_ok = get_value(product) || []
    tags.inject("") do |s, tag|
      s << "<input type='#{type_button}' name='specification_#{tag.idurl}' title='idurl=#{tag.idurl}' value='#{tag.idurl}' #{ tag_idurls_ok.include?(tag.idurl) ? 'checked' : nil} />#{tag.label}"
    end
  end

  def get_specification_html() "<span title=\"#{tags.collect(&:label).join(', ')}, level=#{level}\">#{label}</span>#{specification_html_suffix}" end

  # this is included in a form
  def get_specification_edit_html()
    super() << "<div class=\"field\">
                   <span>exclusive tag?</span>
                    <input type='checkbox' name='is_exclusive' value='1' #{ is_exclusive ? 'checked' : nil} />
                   <br/>
                   <input type='text' style=\"width:95%;\" value='" << tags.collect(&:label).join(', ') << "' />
                </div>"
  end

  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string)
    content_string = content_string.strip
    has_space = content_string.include?(' ')
    has_comma = content_string.include?(',')
    raise "error" if has_space and has_comma
    if has_space
      tag_idurls = content_string.split(' ')
    elsif has_comma
      tag_idurls = content_string.split(',')
    else
      tag_idurls = [content_string]
    end
    tag_idurls.each(&:strip!)
    tag_idurls
  end
  def value2xml(value) value.join(', ') end

  # ---------------------------------------------------------------------


  # return 2 arrays of specification_tag_idurls used as minima, maxima in among products
  # minima = intersection of all specification tag idurls
  # maxima = union of all specification tag idurls
  def range(among_products)
    all_tags_idurls = tags.collect(&:idurl)
    min, max = among_products.inject([Set.new(all_tags_idurls), Set.new]) do |sets, product|
      intersection, union = sets
      product_tag_idurls = product.product.get_value(idurl)
      product_tag_idurls ? [i.intersection(product_tag_idurls), u.merge(product_tag_idurls)] : [intersection, union]
    end
    max.size > min.size ? [min, max] : [[], all_tags_idurls]
  end

  #mode is either :comparator or :related
  def is_compatible_grammar(mode) true end

  # this function is overloaded by type
  # and define the kind of filtering operation that can be apply on the value
  # of this field
  def operator_filtering(specification)
    if specification.is_a?(SpecificationTags)
      if is_exclusive
        [ { :key => "is_either", :gui => select_simple(specification.tags) },
          { :key => "is_not", :gui => select_multiple(specification.tags) } ]
      else
        [ { :key => "include_or", :gui => select_simple(specification.tags) },
          { :key => "are_neither", :gui => select_multiple(specification.tags) } ]
      end
    elsif specification.is_a?(SpecificationNumeric)

    end
  end



end

# define a rating value
# aggregations objects are attached for each specificationRating/Product
# value is an Integer
class SpecificationRating < Specification

  key :min_rating, Integer, :default => 1
  key :max_rating, Integer, :default => 5
  key :user_category, String, :default => 'user'

  def self.initialize_from_xml(xml_node)
    specification_rating = super(xml_node)
    specification_rating.min_rating = Integer(xml_node['min_rating'])
    specification_rating.max_rating = Integer(xml_node['max_rating'])
    specification_rating.user_category = xml_node['user_category']
    specification_rating
  end

  def generate_xml(top_node)
    node_specification_rating = super(top_node)
    node_specification_rating['min_rating'] = min_rating.to_s
    node_specification_rating['max_rating'] = max_rating.to_s
    node_specification_rating['user_category'] = user_category
    node_specification_rating
  end

  def product_template_comment() "a number between #{min_rating} and #{max_rating}" end

  # define the distance between  2 products for this specification
  def distance_metric(product1, product2) (get_value(product1) - get_value(product2)).abs end

  def get_value_01(product)
    #Root.rule3(get_value(product).to_f, min_rating.to_f, max_rating.to_f)
    get_value(product).to_f
  end

  def get_value_in_min_max_rating(product) get_value_in_min_max_rating_bis(get_value_01(product)) end

  def get_value_in_min_max_rating_bis(value_01)
    value_01 * (max_rating - min_rating) + min_rating
  end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is a float between 0 and 1

  def get_value_html(product)
    if value = get_value_01(product)
      stars_html(value)
    end
  end

  def stars_html(value_01)
    Root.stars_html(get_value_in_min_max_rating_bis(value_01), max_rating)
  end


  # this is included in a form
  def get_value_edit_html(product)
    "<div class=\"field\">
      <span>rating (min=#{min_rating}, max=#{max_rating})</span>
      <input type='text' name='specification_#{idurl}' value='#{get_value(product)}' />
    </div>"
  end

  def get_specification_html()
    suffix = "#{Root.icon_star}#{specification_html_suffix}"
    "<span title=\"rating (min=#{min_rating}, max=#{max_rating})\">#{label} #{suffix} </span>"
  end

  # this is included in a form
  def get_specification_edit_html()
    super() << "<div class=\"field\">
                   min=<input name=\"min_rating\" type='text' value=\"#{min_rating}\" size=\"2\" />
                   max=<input name=\"max_rating\" type='text' value=\"#{max_rating}\" size=\"2\" />
                </div>"
  end


  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string) Float(content_string.strip) end
  def value2xml(value) value.to_s end

  # ---------------------------------------------------------------------

  def should_display?(product) false end

end

# define 2 sub specifications of same type (subtype of continoueus)
# first specification aggregated value < second specification aggregated value
class SpecificationInterval < Specification

  key :class_name, String
  many :interval, :class_name => "Specification", :polymorphic => true

  def specification_min() interval.first end
  def specification_max() interval.last end

  def self.initialize_from_xml(xml_node)
    specification_interval = super(xml_node)
    specification_interval.class_name = xml_node['class_name']
    specification_interval.read_xml_list(xml_node, "Specification", :container_tag => 'ranges', :set_method_name => 'interval')
    specification_interval.interval.size
    raise "****** error #{xml_node.inspect}" unless specification_interval.interval.size == 2
    specification_interval
  end

  def generate_xml(top_node)
    node_specification_interval = super(top_node)
    node_specification_interval['class_name'] = class_name
    Root.write_xml_list(xml_node, interval, 'ranges')
    node_specification_interval
  end

  def get_value_01(product)
    # todo
    0.0
  end

  def product_template_comment() "[#{class_name}, #{class_name}]" end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array made of the value of min specifications float between 0 and 1
  def get_value(product)
    value_min = specification_min.get_value_html(product)
    value_max = specification_max.get_value_html(product)
    [value_min, value_max] if value_min or value_max
  end

  def get_value_html(product)
    if get_value(product)
      "#{specification_min.get_value_html(product)} #{specification_min.get_value_html(product)}"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    specification_min.get_value_edit_html(product) << specification_max.get_value_edit_html(product)
  end

  def get_specification_html() "<span title=\"interval of class#{class_name}\">#{label}</span>" end

  # this is included in a form
  def get_specification_edit_html()
    super()
  end

  SEPARATOR_INERVAL = '-@@-'
  def xml2value(content_string)
    content_string_min, content_string_max = content_string.split(SEPARATOR_INERVAL)
    value_min = content_string_min ? specification_min.xml2value(content_string_min) : nil
    value_max = content_string_max ? specification_max.xml2value(content_string_max) : nil
    [value_min, value_max]
  end

  def value2xml(value)
    xml_min = value.first ? specification_min.value2xml(value.first) : nil
    xml_max = value.last ? specification_max.value2xml(value.last) : nil
    "#{xml_min}#{SEPARATOR_INERVAL}#{xml_max}"
  end
  # ---------------------------------------------------------------------


end


# ----------------------------------------------------------------------------------------
# Continous (Abstract)
# ----------------------------------------------------------------------------------------

class SpecificationContinous < Specification

  key :value_min, Object
  key :value_max, Object
  key :value_format, String

  # self.initialize_from_xml(xml_node) and generate_xml are defined in sub classes

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array made of the value of min specifications float between 0 and 1


  def get_value_html(product)
    if get_value(product)
      "#{format_value(get_value(product))}#{specification_html_suffix}"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    specification_continous_value =  get_value(product)
    specification_continous_value ||= ""
    "<div class=\"field\">
        <input type='text' name='specification_#{idurl}' value='#{specification_continous_value}' />
     </div>"
  end

  def get_specification_html() "<span title=\"specification #{self.class}\">#{label}</span>#{specification_html_suffix}" end

  # this is included in a form
  def get_specification_edit_html()
    super() << "<div class=\"field\">
                   format <input type='text' name='format' value='#{value_format}' />
                </div>"
  end


  # ---------------------------------------------------------------------


  # return the min max values
  def range(among_products)
    l = among_products.collect { |p| get_value(p)  }.sort!
    (l and min = l.min < max = l.max) ? [min, max] : [value_min, value_max]
  end

  def distance_metric(product1, product2)
    Float(get_value(product1) - get_value(product2)).abs
  end

end

class SpecificationNumeric < SpecificationContinous

  def self.initialize_from_xml(xml_node)
    specification_numeric = super(xml_node)
    specification_numeric.value_min = Float(xml_node['value_min'] || 0.0)
    specification_numeric.value_max = Float(xml_node['value_max'] || 1000.0)
    specification_numeric.value_format = xml_node.attributes['format'] || "%.2f"
    specification_numeric
  end

  # self.initialize_from_xml(xml_node) is defined in sub classes
  def generate_xml(top_node)
    node_specification_numeric = super(top_node)
    node_specification_numeric['value_min'] = value_min.to_s
    node_specification_numeric['value_max'] = value_max.to_s
    node_specification_numeric['format'] = value_format
    node_specification_numeric
  end

  def format_value(numeric_value)
    begin
      value_format % numeric_value
    rescue
      numeric_value.to_s
    end

  end

  def get_value_01(product)
    value = get_value(product)
    Root.rule3(value, value_min, value_max) if value
  end

  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string) Float(content_string.strip) end
  def value2xml(value) value.to_s end

  def product_template_comment() "a number between #{value_min} and #{value_max}" end

end

class SpecificationDate < SpecificationContinous

  YEAR_IN_SECONDS = 60 * 60 * 24 * 365

  def self.initialize_from_xml(xml_node)
    specification_date = super(xml_node)
    specification_date.value_min = (date_min = xml_node['value_min']) ?  xml2date(date_min) : Time.now - 10 * YEAR_IN_SECONDS
    specification_date.value_max = (date_max = xml_node['value_max']) ?  xml2date(date_max) : Time.now + 10 * YEAR_IN_SECONDS
    specification_date.value_format = xml_node['format'] || Root.default_date_format
    specification_date
  end
  def self.xml2date(date) Time.parse(date) end

  # self.initialize_from_xml(xml_node) is defined in sub classes
  def generate_xml(top_node)
    node_specification_date = super(top_node)
    node_specification_date['value_min'] = SpecificationDate.date2xml(value_min)
    node_specification_date['value_max'] = SpecificationDate.date2xml(value_max)
    node_specification_date['format'] = value_format
    node_specification_date
  end
  def self.date2xml(x) x.strftime(Root.default_date_format) end

  # see http://ruby-doc.org/core-1.9/classes/Time.html#M000314
  def format_value(date) date.strftime(value_format) end

  def get_value_01(product) Root.rule3(get_value(product), value_min, value_max) end


  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string) SpecificationDate.xml2date(content_string.strip) end
  def value2xml(value) SpecificationDate.date2xml(value) end

  def product_template_comment() "a date between #{value2xml(value_min)} and #{value2xml(value_max)}" end

end

# ----------------------------------------------------------------------------------------
# Condition
# ----------------------------------------------------------------------------------------

# value is a boolean
class SpecificationCondition < Specification

  def self.initialize_from_xml(xml_node)
    specification_condition = super(xml_node)
  end

  def generate_xml(top_node)
    node_specification_condition = super(top_node)
  end

  def get_value_01(product) get_value(product) ? 1.0 : 0.0 end

  # ---------------------------------------------------------------------
  # to display the matrix
  # value is an array of tag.idurl

  def get_value_html(product)
    unless (value = get_value(product)).nil?
      "<img src=\"/images/icons/opinion_#{value ? 'ok' : 'ko' }.jpg\" />"
    end
  end

  # this is included in a form
  def get_value_edit_html(product)
    "<input type='checkbox' name='specification_#{idurl}' title='idurl=#{idurl}' value='#{idurl}' #{ get_value(product) ? 'checked' : nil} />#{label}"
  end

  def product_template_comment() "true or false" end

  # ---------------------------------------------------------------------

  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string)
    content_string = content_string.strip
    content_string != "" and content_string.downcase != "false"
  end
  def value2xml(value) value.to_s end

  def should_display?(product) super(product) and get_value(product) end

end

# ----------------------------------------------------------------------------------------
# Computed (value comes for combination of other specification)
# ----------------------------------------------------------------------------------------

# value is the result of the formula !
class SpecificationComputed < Specification

  key :formula, String

  def self.initialize_from_xml(xml_node)
    specification_computed = super(xml_node)
    specification_computed.formula_string = xml_node['formula']
    raise "error, no formula" unless specification_computed.formula_string
    specification_computed
  end

  def generate_xml(top_node)
    node_specification_computed = super(top_node)
    node_specification_computed['formula'] = formula_string
    node_specification_computed
  end

  def get_value_01(product) 0.0 end

  # ---------------------------------------------------------------------
  def get_value_html(product) get_value(product).to_s end

  # this is included in a form
  def get_value_edit_html(product) nil end

  # computation
  def get_value(product)
    FormulaEvaluator.new(knowledge, product).eval(formula)
  end

  # ---------------------------------------------------------------------
  # convert value to string (and reverse for dumping data product's specification value)
  def xml2value(content_string) raise "oups" end
  def value2xml(value) raise "oups" end

  # formula evaluator
  class Evaluator

    def initialize(knowledge, product)
      @knowledge = knowledge
      @product = product
    end

    def eval(formula) self.eval_instance_eval(formula) end

    # language itself
    def specificationIs(idurl_specification)
      @knowledge.get_specification_by_idurl(specification_idurl).get_value(product)
    end

  end

end

# ----------------------------------------------------------------------------------------
# Text (use for label, description, etc...)
# ----------------------------------------------------------------------------------------

# value is line of text
class SpecificationText < Specification
  def product_template_comment() "a string" end
end

# value is a URL
class SpecificationTextarea < Specification
  def get_value_html(product)
    if url = get_value(product)
      "<a href=\"#{knowledge.clean_url(url, product)}\">link</a>"
    end
  end

  def product_template_comment() "an url, like files/toto.html" end

end

class SpecificationImage < Specification

  def get_value_html(product)
    if url = get_value(product)
      "<img src=\"#{knowledge.clean_url(url, product)}\" width=\"100\" height=\"100\" />"
    end
  end

  def product_template_comment() "an url, like images/mabelle_image.png" end


end

class SpecificationUrl < Specification
  def get_value_html(product)
    if url = get_value(product)
      "<a href=\"#{knowledge.clean_url(url, product)}\">link</a>"
    end
  end

  def product_template_comment() "an url, like <![CDATA[ http//amazon.com/iphone.html ]]>" end

end
  
# define a specification with no value
class SpecificationHeader < Specification

  def color_from_status(product) "lightblue" end

  def get_value_edit_html(product) "" end

end

