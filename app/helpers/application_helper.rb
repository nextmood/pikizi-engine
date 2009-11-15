# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def height_xml_editor() "500px" end


  def compute_body_id(controller_action_name)
    case controller_action_name
      when "home/index" then "home" # ok
      when "home/test_products_search" then "products"  # search result ok      products_results
      when "home/test_results" then "results"  # result page quizz   ko (menu issue?)
      when "home/test_box" then "products"   # global box   ko (inside)
      when "home/test_quizze" then "quizze"   # quizze  #number of answer wrong position
      when "home/test_product_alone" then "prodResults"  # ok   the product/show
      when "home/test_product_page_results" then   "prodResults"  # one product / results

      
      else  controller_action_name
    end
  end

  def colored_confidence(question)
    "<span style=\"background-color:#{question.confidence < 1 ? 'orange' : 'green'};\">confidence=#{'%d' % (question.confidence * 100)}%</span>"
  end

end
