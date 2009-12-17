# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def height_xml_editor() "500px" end


  def compute_body_id(controller_action_name)
    case controller_action_name
      when "home/index" then "home" # ok
      when "home/test_products_search" then "products"  # search result ok      products_results
      when "home/myresults" then "results"  # result page quizz   ko (menu issue?)
      when "home/test_box" then "products"   # global box   ko (inside)
      when "home/myquiz" then "quizz"   # quizze  #number of answer wrong position
      when "home/test_product_alone" then "prodResults"  # ok   the product/show
      when "home/test_product_page_results" then   "prodResults"  # one product / results
      
      else  controller_action_name
    end
  end

  def colored_confidence(question)
    "<span style=\"background-color:#{question.confidence < 1 ? 'orange' : 'green'};\">confidence=#{'%d' % (question.confidence * 100)}%</span>"
  end

  def colored_weight(weight)
    color_weight =  if weight > 0.0
                      "green"
                    elsif weight < 0.0
                      "red"
                    else
                      "lightgray"
                    end
    "<div style='width:50px; background-color:#{color_weight}'>#{'%4.2f' % weight}</div>"
  end

end
