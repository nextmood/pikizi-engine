require "set"

module Pikizi

require 'xml'

PK_LOGGER = Logger.new(STDOUT)
PK_LOGGER.level = Logger::DEBUG

# The root of all XML/objects of Pikizi (Feature, Question, Choice, User, Product, etc...)
class Root
  # abstract class 
  
  attr_accessor :key, :label
  
  def initialize_from_xml(xml_node) 
    self.key = xml_node['key']
    self.label = (node_label = xml_node.find_first('label') and node_label.content) ? node_label.content.strip : nil
  end
  
  def self.create_new_instance_from_xml(xml_node) Pikizi.const_get(xml_node.name.capitalize).new end
  
  def self.create_with_parameters(key, label=nil) o = self.new; o.key = key; o.label = label; o end

  # get all children in xml (according to a xpath from an xml_node) and returns the children object modl
  # of class class_name
  def self.get_collection_from_xml(xml_node, xpath, &block)
    l = []; xml_node.find(xpath).each { |node| l << yield(node) }; l
  end

  def self.get_hash_from_xml(xml_node, xpath, method_key, &block)
    raise "no xml_node" unless xml_node
    h = {}; xml_node.find(xpath).each { |node| x = yield(node); h[x.send(method_key)] = x }; h
  end

  # first argument is always a xml node
  def self.create_from_xml(xml_node) 
    (x = self.create_new_instance_from_xml(xml_node)).initialize_from_xml(xml_node); x
  end
  
  def generate_xml(top_node, tag_name=nil) 
    unless tag_name
      tag_name = self.class.to_s.downcase
      tag_name.slice!("pikizi::")
    end
    new_node = XML::Node.new(tag_name)
    top_node.is_a?(XML::Document) ? top_node.root = new_node : top_node << new_node
    new_node['key'] = key if key
    if label
      new_node << (node_label = XML::Node.new('label'))
      node_label['lang'] = 'en'
      node_label << label
    end
    new_node
  end
  
  # to convert v.strftime(Root.default_date_format)
  def self.default_date_format() "%Y/%m/%d %H:%M:%S" end
  
  def to_xml(key=nil)
    doc = XML::Document.new

    generate_xml(doc)
    if key
      #doc.compression = 1 ;
      doc.save self.class.filename_data(key)
    else
      doc.to_s(:indent => true)
    end
  end

  def save() to_xml(key) end

  def self.key_exist?(key) File.exist?(filename_data(key)) end

  # return a list of keys available on file system
  def self.xml_keys()
    Dir.new(directory_data).entries.inject([]) do |l, entry|
      filename = entry.to_s
      last_char_index = filename.size - 1
      filename[last_char_index - 3 .. last_char_index] == ".xml" ? l << filename[0 .. last_char_index - 4] : l
    end
  end

  def self.directory_data
    class_name = self.to_s.downcase; class_name.slice!("pikizi::")
    "db/xml/#{class_name}s"
  end

  def self.filename_data(key) "#{directory_data}/#{key}.xml" end


end



  

end