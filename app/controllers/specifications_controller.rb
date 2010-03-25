class SpecificationsController < ApplicationController

  # this a rjs
  def delete()
    specification = Specification.find(params[:id])
    product = Product.find(params[:product_id])
    specification.destroy # recursive
    render :update do |page|
      page.replace("list_specifications", :partial => "/specifications/list", :locals => { :knowledge => product.knowledge, :product => product } )
    end

  end


end
