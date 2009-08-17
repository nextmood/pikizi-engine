class ProductsController < ApplicationController
  # GET /products
  # GET /products.xml
  def index
    @products = Product.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @products }
    end
  end

  # GET /products/1
  # GET /products/1.xml
  def show
    @product = Product.find(params[:id])

    respond_to do |format|
      format.html # show_by_key.html.erb
      format.xml  { render :xml => @product }
    end
  end

  @compteur = 0
  def bar_progress_loading
    @compteur += 10
    @compteur
  end


end
