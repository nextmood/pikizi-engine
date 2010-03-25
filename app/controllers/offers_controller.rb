require 'offer'

class OffersController < ApplicationController

    # this a rjs
  def delete()
    offer = Offer.find(params[:id])
    product = Product.find(params[:product_id])
    offer.destroy # recursive
    render :update do |page|
      page.replace("price_table", :partial => "/offers/list", :locals => { :product => product } )
    end
  end

  def create
    product = Product.find(params[:product_id])
    render :update do |page|
      page.replace("price_table", :partial => "/offers/new", :locals => { :product => product } )
    end
  end

end
