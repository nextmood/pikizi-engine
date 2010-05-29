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

  # options destroy attached opinions
  def destroy(also_opinions=false)
    opinions.each(&:destroy) if also_opinions
    super()  
  end

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

  def update_status(all_products)
    opinions.each { |opinion| opinion.update_status(all_products) }
  end
  
  # create a collection from a file
  def self.import(knowledge, author, filename_xml)
    doc = XML::Document.string(filename_xml.read)
    node_opinions = doc.root
    raise "first tag of xml should be \"opinions\",  got #{(node_opinions ? node_opinions.name : nil).inspect}" unless node_opinions.name == "opinions"

    ocollection = Ocollection.new(:label => node_opinions["label"] || filename_xml.original_filename, :author => node_opinions["author"] || author)
    hash_id_review = {}; hash_id_paragraph = {}; default_dimension_rating = knowledge.dimension_root.id
    node_opinions.children.each do |node_opinion|
      if ["Comparator", "Tip", "Ranking", "Rating"].include?(node_opinion.name)
        class_opinion = Kernel.const_get(node_opinion.name)
        new_opinion = class_opinion.send("import_from_xml", knowledge, node_opinion, hash_id_review, hash_id_paragraph, default_dimension_rating)
        new_opinion.update_status
        ocollection.add(new_opinion)
      else
        puts "WRONG opinion name=#{node_opinion.name}" unless node_opinion.name == "text"
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