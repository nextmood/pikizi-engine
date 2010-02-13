

require 'xml'
require 'digest/md5'


# The root of all XML/objects of Pikizi (Feature, Question, Choice, User, Product, etc...)
class Root
  # abstract class

  # ---------------------------------------------------
  # utilities


  # always return a value between 0.0 and 1.0 for a given x ranging from min to max
  def self.rule3(x, min, max)
    y = Root.rule3_cache(x, Root.rule3_ab(min, max))
    puts "error x=#{x} y=#{y} min=#{min} max=#{max} ab=#{Root.rule3_ab(min, max).inspect}" unless y.in01?
    y
  end
  def self.rule3_cache(x, ab)
    ab.first * x + ab.last
  end
  def self.rule3_ab(min, max)
    a = 1.0 / (max - min)
    [ a , - a * min ]
  end

  # ---------------------------------------------------

  def self.is_main_document() false end

  def self.initialize_from_xml(xml_node)
    o = ((self.is_main_document and xml_node['idurl']) ? self.load(xml_node['idurl']) : nil)
    o ||= self.new
    class_keys = self.keys.collect(&:first).concat(self.associations.collect(&:first))
    o.idurl = xml_node['idurl'] if class_keys.include?("idurl")
    o.label = xml_node['label'] if class_keys.include?("label")
    o.url_description = xml_node['url_description'] if class_keys.include?("url_description")
    o.url_image = xml_node['url_image'] if class_keys.include?("url_image")
    o
  end

  def generate_xml(top_node)
    tag_name = self.class.to_s
    if top_node.is_a?(XML::Document)
      top_node.root = (xml_node = XML::Node.new(tag_name))
    else
      top_node << (xml_node = XML::Node.new(tag_name))
    end

    class_keys = self.class.keys.collect(&:first).concat(self.class.associations.collect(&:first))
    xml_node['idurl'] = idurl if class_keys.include?("idurl")
    xml_node['label'] = label if class_keys.include?("label")

    xml_node['url_description'] = url_description if class_keys.include?("url_description") and url_description
    xml_node['url_image'] = url_image if class_keys.include?("url_image")  and url_image
    xml_node
  end

  def read_xml_list(xml_node, prefix_tag_name, options={})
    container_tag = options[:container_tag]
    set_method_name = options[:set_method_name]
    set_method_name = "#{prefix_tag_name.downcase}s" unless set_method_name
    if container_tag
      sub_node = xml_node.find_first(container_tag)
      #puts "no container tag:#{container_tag.inspect} for node=#{xml_node.inspect} " unless sub_node
      xml_node = sub_node
    end

    if xml_node
      sub_objects = xml_node.children.inject([]) do |l, xml_sub_node|
        #puts "checking xml_sub_node = #{xml_sub_node.name} for prefix #{prefix_tag_name}"
        if xml_sub_node.name.has_prefix(prefix_tag_name)
          #puts "hit..."
          l << Kernel.const_get(xml_sub_node.name).initialize_from_xml(xml_sub_node)
        else
          l
        end
      end
    else
      sub_objects = []
    end
    #puts "assign in #{self.inspect} #{set_method_name}="
    #puts " #{set_method_name}= [" << sub_objects.collect {|x| x.inspect }.join(', ')  << "]"
    self.send("#{set_method_name}=", sub_objects)
  end

  def self.read_xml_list_idurl(xml_node, container_tag)
    sub_node = xml_node.find_first(container_tag)
    if sub_node
      sub_node.content.split(",").collect { |s| s.chomp.strip! }
    else
      []
    end
  end

  def self.write_xml_list_idurl(xml_node, list, container_tag)
    xml_node << (sub_node = XML::Node.new(container_tag))
    sub_node << (list || []).join(', ')
  end

  def self.write_xml_list(xml_node, list, container_tag=nil)
    if list.size > 0
      if container_tag
        xml_node << (node_list = XML::Node.new(container_tag))
      else
        node_list =  xml_node
      end
      list.each { |object| object.generate_xml(node_list) }
    end
    xml_node
  end


  def self.get_entries(path)
    Dir.new("#{path}").entries.inject([]) do |l, entry|
      (entry.has_prefix(".") or entry.has_prefix("..")) ? l : l << entry
    end
  end

  # to convert v.strftime(Root.default_date_format)
  def self.default_date_format() "%Y/%m/%d %H:%M:%S" end


  def self.compute_time
    start = Time.now
    x = yield
    delta = Time.now - start
    puts "-----------------------------------------"
    puts "t=#{delta}, i.e. #{1. / delta}/s"
    puts "-----------------------------------------"
    x
  end

  def self.as_percentage(proba) "(#{'%d' % (proba * 100).round}%)" end

  # convert an object to an xml string
  def to_xml(a_idurl=nil)
    doc = XML::Document.new
    generate_xml(doc)
    doc.to_s(:indent => true)
  end

  def self.load(object_ids)
    if object_ids.is_a?(Array)
      objects = object_ids.is_a?(Mongo::ObjectID) ? self.find(object_ids) : self.find(:all, :conditions => { :idurl => object_ids })
      objects.each(&:link_back)
      objects
    else
      object = object_ids.is_a?(Mongo::ObjectID) ? self.find(object_ids) : self.find(:first, :conditions => { :idurl => object_ids })
      object.link_back if object
      object
    end
  end

  def link_back() end


  def self.stars_html(value, max_rating)
    nb_stars_full = value.round
    s = ""
    max_rating.round.times do |i|
      s << Root.icon_star(i < nb_stars_full).clone
    end
    "<span title=\"rated #{ '%2.1f' % value } out of #{max_rating}\">#{s}</span>"
  end

  def self.icon_star(full=true) "<img src=\"/images/icons/star#{'_empty' unless full}.png\" />" end
  
  def self.duration(nb=1)
    t = Time.now
    nb.times { yield }
    "nb_run=#{nb} average=#{(Time.now - t) / Float(nb)}"
  end

end




class String

  def has_prefix(prefix) self[0..prefix.size-1] == prefix end

  def remove_prefix(prefix) self[prefix.size..self.size-1] end

  def has_suffix(suffix) self[self.size-suffix.size..self.size-1] == suffix end

  def self.is_not_empty(s) s if s and s != "" end

  def extract_external_id
    if has_prefix(prefix = "http://www.facebook.com/profile.php?id=")
      [:facebook, String.is_not_empty(remove_prefix(prefix))]
    elsif has_prefix(prefix = "http://www.twitter.com/profile.php?id=")
      [:twitter, String.is_not_empty(remove_prefix(prefix))]
    end
  end

end

class Float
  def in01?() self >= 0.0 and self <= 1.0 end
end




# extented array
class Array

  # with basic statistical functions

  def stat_sum() inject(0.0) { |s, x| (x.nil? or x.nan?) ? s : s + x } end
  def stat_mean() stat_sum / size.to_f end
  def stat_standard_deviation()
    m = stat_mean
    begin
      Math.sqrt((inject(0.0) { |s, x| x.nan? ? s : s + (x - m)**2 } / size.to_f))
    rescue Exception => e
      raise "error #{e.message} x=#{self.inspect}"
      0.0
    end
  end

  def nb_unique() inject([]) { |l, x| l.include?(x) ? l : l << x }.size  end

  # yield all all possible combinations in an array
  # and return the number of combination (empty set count for one)
  def self.combinatorial(tail, empty_count, &block) self.combinatorial_bis(tail, empty_count, [], 0, &block) end
  def self.combinatorial_bis(tail, empty_count, elt_set, x, &block)
    if tail.size == 0
      if elt_set.size > 0 or empty_count
        block.call(elt_set)
        x += 1
      else
        x
      end
    else
      new_tail = tail.clone
      first_elt = new_tail.shift
      x = self.combinatorial_bis(new_tail, empty_count, elt_set, x, &block)
      x = self.combinatorial_bis(new_tail, empty_count, elt_set.clone << first_elt, x, &block)
    end
    x
  end

end

