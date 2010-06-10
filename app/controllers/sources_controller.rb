require 'source'

class SourcesController < ApplicationController

  def index
    @sources = Source.all
  end

  def show
    @source = Source.find(params[:id])
  end

  # GET or POST sources/search/:source_id
  def search
    @source = Source.find(params[:id])
    label_invite = "search for..."
    @query_string = params[:query_string]
    if @query_string and @query_string.size > 3 and @query_string != label_invite
      #there is a search requested
      @results_as_source_products = @source.search(@query_string)
    else
      # there is no search
      @query_string = label_invite
      @results_as_source_products = nil
    end
  end

  # ghost (look straight online)
  # only_cache
  def show_product
    if params[:sid]
      # we want to see it rel time from source
      @source = Source.find(params[:id])
      @source_product = @source.get_source_product_from_online(params[:sid])
    else
      # get from cache only
      @source_product = SourceProduct.find(params[:id])
    end
  end

end
