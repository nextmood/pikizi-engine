class ProductsController < ApplicationController

  def index
    @products = Product.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  # index.xml.erb
    end

  end

  def show
    @product = Product.first(:idurl => params[:product_idurl])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  # show.xml.erb
    end
  end

end
