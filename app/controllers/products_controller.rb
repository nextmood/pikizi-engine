class ProductsController < ApplicationController


  def show
    @product = Product.first(:idurl => params[:product_idurl])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render(:xml => @product) }
    end
  end

end
