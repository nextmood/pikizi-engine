# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def height_xml_editor() "500px" end


  def compute_body_id(controller_action_name)
    case controller_action_name
      when "home/quizzes" then "home" # ok
      when "home/my_results" then "results"  # result page quizz   ko (menu issue?)
      when "home/my_quiz" then "quizz"   # quizze  #number of answer wrong position
      when "home/my_product" then "prodResults"   # product page for a given quizz
      when "home/product" then "prodResults"   # product alone
      when "home/products_search" then "products"  # search result

      when "home/test_products_search" then "products"  # search result ok      products_results
      when "home/test_box" then "products"   # global box   ko (inside)      
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

  def source_as_html(review)
    if review.source or review.source_url
      s = review.source || "source"
      s = link_to(s, review.source_url) if review.source_url
      " (from #{s})"
    end
  end

end
