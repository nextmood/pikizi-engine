require 'xml'
require 'mongo_mapper'

class Quizze < Root

  include MongoMapper::Document

  key :idurl, String # unique url
  key :label, String # unique url
  
  key :knowledge_id, BSON::ObjectID

  key :knowledge_idurl, String

  key :main_image_url, String
  key :description_url, String

  key :question_idurls, Array
  key :product_idurls, Array

  timestamps!

  def questions() @questions ||= Question.all(:idurl => question_idurls) end
  def products() @products ||= Product.all(:idurl => product_idurls) end

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


  def generate_xml(top_node)
    node_quizze = super(top_node)
    node_quizze["main_image"] = main_image_url
    node_quizze["description"] = description_url
    Root.write_xml_list_idurl(node_quizze, product_idurls, "product_idurls")
    Root.write_xml_list_idurl(node_quizze, question_idurls, "question_idurls")
    node_quizze
  end

end