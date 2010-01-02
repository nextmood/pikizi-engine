require 'xml'
require 'mongo_mapper'

class Quizze < Root

  include MongoMapper::Document
  
  key :idurl, String, :index => true # unique url
  key :knowledge_idurl, String
  
  key :label, String # unique url
  key :main_image_url, String
  key :description_url, String
  
  key :question_idurls, Array
  key :product_idurls, Array
  
  timestamps!

  def get_knowledge() @knowledge ||= Knowledge.load(knowledge_idurl) end

  def self.is_main_document() true end

  def questions() @questions ||= Question.load(question_idurls) end
  def products() @products ||= Product.load(product_idurls) end

  # return all questions within a given dimension
  def questions_4_dimension(dimension) questions.select { |question| question.dimension == dimension } end

  # returns all dimensions of this quizze
  def dimensions()
    @dimensions ||= questions.inject([]) do |l, question|
      question_dimension = question.dimension
      l << question_dimension unless l.include?(question_dimension) or question_dimension == "unknown"
      l
    end
  end
  
  def self.initialize_from_xml(knowledge, xml_node)
    quizze = super(xml_node)
    quizze.knowledge_idurl = knowledge.idurl
    quizze.main_image_url = xml_node["main_image"]
    quizze.description_url = xml_node["description"]
    quizze.product_idurls = read_xml_list_idurl(xml_node, "product_idurls")
    quizze.product_idurls = knowledge.product_idurls if quizze.product_idurls.size == 0

    quizze.question_idurls = read_xml_list_idurl(xml_node, "question_idurls")
    quizze.question_idurls = knowledge.question_idurls if quizze.question_idurls.size == 0

    quizze.save
    quizze
  end



  def generate_xml(top_node)
    node_quizze = super(top_node)
    node_quizze["main_image"] = main_image_url
    node_quizze["description"] = description_url
    Root.write_xml_list_idurl(node_quizze, product_idurls, "product_idurls")
    Root.write_xml_list_idurl(node_quizze, question_idurls, "question_idurls")
    node_quizze
  end

end