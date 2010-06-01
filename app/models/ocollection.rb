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

  #to remove after...
  def self.init_censor_original_datas
    Ocollection.first.opinions.each do |opinion|
      operator_type = if x = opinion.censor_comment and x = x.split('"') and x.size > 1
        puts "inversion for #{opinion.censor_comment}"
        should_be = x[1]
        instead_of= x[3]
        raise "error" unless x[3] == opinion.operator_type
        opinion.update_attributes(:operator_type => x[1])
        x[3]
      else
        opinion.operator_type
      end
      pf1 = opinion.products_filters_for("referent").first
      pf2 = opinion.products_filters_for("compare_to").first
      raise "error #{pf1.class} #{pf2.class}" if !pf1.is_a?(ProductsFilterAnonymous) or (pf2 and !pf2.is_a?(ProductsFilterAnonymous))
      pf1 = pf1.display_as.remove_tags_html if pf1
      pf2 = pf2.display_as.remove_tags_html if pf2
      puts "#{pf1.inspect} #{pf2.inspect}"
      opinion.update_attributes(:censor_original_datas => {
              :products_queries => [pf1, pf2].compact, # list of sentences identifying products
              :comparator => operator_type })  # the original
    end
    true
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