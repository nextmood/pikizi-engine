class SpecificationsController < ApplicationController

  # this a rjs
  def delete()
    specification = Specification.find(params[:id])
    product = Product.find(params[:product_id])
    specification.destroy # recursive
    render :update do |page|
      page.replace("list_specifications", :partial => "/specifications/list", :locals => { :product => product } )
    end

  end

  # return the list of specifications/value for the current products_query / knowledge
  def index
    @products = @current_products_query.execute_query
  end

end
