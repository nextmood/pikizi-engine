# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def height_xml_editor() "500px" end


  def compute_body_id(controller_action_name)
    case controller_action_name
      when "home/index" then "home"
      when "home/test_products" then "products"
      when "home/test_results" then "results"
      else  controller_action_name
    end
  end

end
