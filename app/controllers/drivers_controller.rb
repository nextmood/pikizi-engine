require 'driver'

class DriversController < ApplicationController

  def index
    @drivers = @current_knowledge.drivers
    @products = @current_knowledge.products
  end

  #
  def test_instapaper
    if url = params[:url]
      @html_instapaper = TextSource.save_to_instapaper(url)
    end
  end

  def show
    @driver = Driver.find(params[:id])
  end

  # GET or POST /search_in_drivers
  # multi threading (not native)
  def search
    @drivers = @current_knowledge.drivers
    param_drivers_selected = params[:drivers_selected] || []
    @drivers_selected = @drivers.select { |d| param_drivers_selected.include?(d.source) }
    @drivers_selected = @drivers if @drivers_selected.size == 0
    no_time = Time.now - (60 * 60 * 24 * 365 * 10)
    label_invite = ""
    @query_string = params[:query_string]
    if @query_string and @query_string.size > 3 and @query_string != label_invite
      #there is a search requested
      @results_as_driver_products = []
      @results_hash_time = {}; t0_total = Time.now
      threads = @drivers_selected.collect do |d|
        Thread.new do
          t0 = Time.now
          driver_results = d.search(@query_string)
          @results_hash_time[d.source] = Time.now - t0
          @results_as_driver_products.concat(driver_results)
        end
      end
      # wait for each thread to finish
      threads.each(&:join)
      @time_total = Time.now - t0_total 
      @results_as_driver_products.sort! { |d1, d2|  (d2.written_at || no_time) <=> (d1.written_at || no_time)}
    else
      # there is no search
      @query_string = label_invite
      @results_as_driver_products = nil
    end
  end

  # ghost (look straight online)
  # only_cache
  # GET /drivers/show_product/:id           :id is a DriverProduct.id (look up in db)
  # GET /drivers/show_product/:id?sid=:sid  :id is a Driver.id, :sid is a local product id for online lookup
  def show_product
    puts "show product params=#{params.inspect}"
    if params[:sid]
      # we want to see it rel time from driver
      @driver = Driver.find(params[:id])
      @driver_product = @driver.get_details(params[:sid])
    else
      # get from DB only
      @driver_product = DriverProduct.find(params[:id])
      @driver = @driver_product.driver
    end
  end

  # add (or remove) a driver product from the monitoring list
  def add_driver_product
    driver = Driver.find(params[:driver_id])
    driver_product_sid = params[:driver_product_sid]
    raise "error already existing #{driver_product_sid}" if driver.driver_products.find(:sid => driver_product_sid)
    driver_product = driver.get_details(driver_product_sid)
    driver_product.driver_id = driver.id
    driver_product.pkz_product_ids = @current_products_query.execute_query.collect(&:id)
    driver_product.save
    redirect_to "/drivers/show_product/#{driver_product.id}"
  end

    # remove a driver product from the monitoring list
  def remove_driver_product
    DriverProduct.find(params[:driver_product_id]).destroy
    redirect_to "/search_in_drivers"
  end

  # thi sis a rjs
  def download_reviews
    puts params.inspect
    @driver_product = DriverProduct.find(params[:id])
    @driver_reviews = [] # @driver_product.download_reviews()
    render :update do |page|
      page.replace("new_reviews", "la liste des reviews")
    end
  end
end
