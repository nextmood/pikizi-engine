

require 'xml'
require 'digest/md5'


# The root of all XML/objects of Pikizi (Feature, Question, Choice, User, Product, etc...)
class Root
  # abstract class

  def self.erase_db()
    Question.find(:all).each(&:destroy)
    Quizze.find(:all).each(&:destroy)
    Product.find(:all).each(&:destroy)
    Knowledge.find(:all).each(&:destroy)
    #User.find(:all).each(&:destroy)
    Knowledge.initialize_from_xml("cell_phones")
    "database reset"
  end

  def self.update_users_idurl()
    User.find(:all).each do |user|
      if user.rpx_identifier
        user.idurl = Digest::MD5.hexdigest(user.rpx_identifier)
        puts "updating user=#{user.inspect}"
        user.save
      else
        puts "destroying user=#{user.inspect}"
        puts user.inspect
        user.destroy
      end
    end
  end
  
  def self.is_main_document() false end

  def self.initialize_from_xml(xml_node)
    o = self.is_main_document ? self.get_from_idurl(xml_node['idurl'], nil, :no_link_back => true) : nil
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
    xml_node << (sub_node = XML::Node.new('container_tag'))
    sub_node << (list || []).join(', ')
  end

  def self.write_xml_list(xml_node, list, container_tag=nil)
    if container_tag
      xml_node << (node_list = XML::Node.new('container_tag'))
    else
      node_list =  xml_node
    end
    list.each { |object| object.generate_xml(node_list) }
    xml_node
  end

  # retrieve a main document from it's idurl (unique!)
  # also works for a list of idurls'
  #
  def self.get_from_idurl(idurl, knowledge=nil, options = {})
    if idurl.is_a?(Array)
      objects = self.find(:all, :conditions => { :idurl => idurl })
      objects.each { |o| o.link_back(knowledge) } unless options[:no_link_back]
      objects
    else
      object = self.find(:first, :conditions => { :idurl => idurl })
      object.link_back(knowledge)  if object and  !options[:no_link_back]
      object
    end
  end

  def self.get_entries(path)
    Dir.new("#{path}").entries.inject([]) do |l, entry|
      [".", ".."].include?(entry) ? l : l << entry
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

end




class String

  def has_prefix(prefix) self[0..prefix.size-1] == prefix end

  def remove_prefix(prefix) self[prefix.size..self.size-1] end

  def has_suffix(suffix) self[self.size-suffix.size..self.size-1] == suffix end

end