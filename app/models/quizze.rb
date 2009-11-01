require 'xml'
require 'mongo_mapper'

class Quizze < Root

  include MongoMapper::Document
  
  key :idurl, String, :index => true # unique url

  key :label, String # unique url

  key :question_idurls, Array
  key :product_idurls, Array

  timestamps!
  
  def self.is_main_document() true end

  def questions() @questions ||= Question.get_from_idurl(question_idurls, knowledge)  end

  key :product_idurls, Array
  def products() @products ||= Product.get_from_idurl(product_idurls, knowledge) end

  attr_accessor :knowledge

  def link_back(knowledge)
    self.knowledge = knowledge
  end

  def self.initialize_from_xml(knowledge, xml_node)
    quizze = super(xml_node)
    quizze.product_idurls = read_xml_list_idurl(xml_node, "product_idurls")
    quizze.question_idurls = read_xml_list_idurl(xml_node, "question_idurls")
    quizze.save
    quizze
  end

  def generate_xml(top_node)
    node_quizze = super(top_node)
    Root.write_xml_list_idurl(node_quizze, product_idurls, "product_idurls")
    Root.write_xml_list_idurl(node_quizze, question_idurls, "question_idurls")
    node_quizze
  end

end