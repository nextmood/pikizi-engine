require 'xml'
require 'opinion'

# this is a list of opinions (use in import)

class Ocollection

  include MongoMapper::Document

  key :label, String
  key :author, String
  timestamps!
  
  key :opinion_ids, Array # an array of opinions id
  many :opinions, :in => :opinion_ids

  attr_accessor :cache_opinions
  
  # create a new Ocollection (not saved) with a list of opinions
  #for use with render to_xml
  def self.new_with_opinions(author, label, opinions)
    ocollection = Ocollection.new(:label => label, :author => author)
    ocollection.cache_opinions = opinions
    ocollection
  end

  def to_xml
    doc = XML::Document.new
    doc.root =  (node_opinions = XML::Node.new("opinions"))

    node_opinions["author"] = author
    node_opinions["label"] = label
    puts "size=#{cache_opinions.size}"
    (cache_opinions || opinions).each { |opinion| node_opinions << opinion.to_xml_bis }
    doc.to_s
  end

  # create a collection from a file
  def self.import(knowledge, author, filename_xml)
    doc = XML::Document.string(filename_xml.read)
    node_opinions = doc.root
    raise "first tag of xml should be \"opinions\",  got #{(node_opinions ? node_opinions.name : nil).inspect}" unless node_opinions.name == "opinions"
    default_products_extract = node_opinions["default_product_selector_1"]
    default_products = Product.get_products_from_text(knowledge, default_products_extract)
    ocollection = Ocollection.new(:label => node_opinions["label"] || filename_xml.original_filename, :author => node_opinions["author"] || author)
    node_opinions.children.each do |node_opinion|
      if ["Comparator", "Tip", "Ranking", "Rating"].include?(node_opinion.name)
        puts "node_opinion.name=#{node_opinion.name}"
        class_opinion = Kernel.const_get(node_opinion.name)
        new_opinion = class_opinion.send("import_from_xml", knowledge, node_opinion, default_products)
        ocollection.add(new_opinion)
      else
        puts "WRONGopinion name=#{node_opinion.name}"
      end
    end
    ocollection
  end

  # nb opinions in this collection
  def nb_opinions() opinion_ids.size end

  # adding an opinion to this collection
  def add(opinion, should_save=true)
    self.opinions << opinion
    update_attributes(:opinion_ids => opinion_ids) if should_save
  end

  # removing this opinion from the collection
  def remove(opinion_id, should_save=true)
    self.opinion_ids.delete(opinion_id)
    self.opinions.delete_if { |o| o.id == opinion_id }    
    update_attributes(:opinion_ids => opinion_ids) if should_save
  end
  
end