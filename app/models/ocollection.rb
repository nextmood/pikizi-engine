require 'xml'

# this is a list of opinions (use in import)

class Ocollection

  include MongoMapper::Document

  key :label, String

  key :opinion_ids, Array # an array of opinions id
  many :opinions, :in => :opinion_ids

  key :author, String

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
  def self.import(user, label, filename_xml)
    puts "import #{label} by #{user.rpx_username}"
    doc = XML::Document.string(filename_xml.read)
    xml_node = doc.root
    raise "first tag of xml should be \"opinions\",  got #{(xml_node ? xml_node.name : nil).inspect}" unless xml_node.name == "opinions"
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