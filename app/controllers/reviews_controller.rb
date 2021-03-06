require 'opinion'
require 'paginator'


class ReviewsController < ApplicationController


  # api for eric
  def eric
    @max_nb_reviews = (params[:max_nb_reviews] || 10)    
    @reviews = @current_knowledge.reviews.all({ :limit => @max_nb_reviews })

    @source_categories = params[:source_categories]
    @source_categories ||= Review.categories.collect { |category_name, weight| category_name }

    # @reviews = @reviews[0..10]
    respond_to do |format|
      format.html # eric.html.erb
      format.xml  { render(:xml => Review ) }
    end
  end

  # return a xml file of revies
  # /reviews/nltk_sources.xml
  def nltk_sources
    @reviews = Review.all(:limit => 3, :category => "amazon", :state => "to_analyze")
    respond_to do |format|
      format.html # nltk_sources.html.erb
      format.xml # nltk_sources.xml.builder
    end
  end


  # GET /reviews/:review_id
  def show
    @review = Review.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  # GET /reviews/drivers
  def drivers
    @products = @current_knowledge.get_products    
  end

  # GET /reviews/drivers_update
  def drivers_update
    nb_products, nb_product_updated, nb_reviews_imported = Product.update_from_driver(@current_knowledge, params[:source])
    flash[:notice] = "nb_products=#{nb_products}, nb_product_updated=#{nb_product_updated} nb_reviews_imported=#{nb_reviews_imported}"
    redirect_to "/reviews/drivers"
  end

  def recompute_all_states
    @current_knowledge.recompute_all_states
    redirect_to("/reviews")
  end

  # trigger an event for all opinions in this review
  # recompute the review/paragraphs state
  def trigger_event
    event_name = params[:event_name]
    review = Review.find(params[:id])
    nb_opinions, nb_opinions_moved = 0,0
    review.opinions.each do |opinion|
      begin
        opinion.send("#{event_name}!")
        nb_opinions_moved += 1
      rescue
        puts "transition for opinion #{opinion.id} in state #{opinion.state} with event  #{event_name} impossible "
      end
      nb_opinions += 1
    end
    review.paragraphs.collect(&:update_status)
    review.update_status
    flash[:notice] = "#{nb_opinions_moved} opinion(s) moved for #{nb_opinions} opinions total"
    redirect_to "/reviews/edit/#{review.id}"
  end


  # list all reviews for current knowledge
  def index
    if related_product_label = params[:search] and related_product_label = params[:search][:related_product]
      @related_product = Product.first(:label => related_product_label)
    end
    @max_nb_reviews = params[:max_nb_reviews] || 100
    @date_oldest = if date_oldest = params[:date_oldest]
      Date.new(Integer(date_oldest["year"]), Integer(date_oldest["month"]), Integer(date_oldest["day"]))
    else
      Date.today - 1000
    end

    @output_mode = params[:output_mode] || "standard"
    @source_categories = params[:source_categories]
    @source_categories ||= Review.categories.collect { |category_name, weight| category_name }
    @state_names = params[:state_names]
    @state_names ||= Review.list_states.collect(&:first)


    select_options = { :category => @source_categories,
                       :state => @state_names,
                       :limit => @max_nb_reviews,
                       :written_at => { '$gt' => @date_oldest.to_time },
                       :order => "written_at DESC"  }
    select_options["product_ids"] = @related_product.id if @related_product

    # puts "selection options=#{select_options.inspect}"
    @reviews = Review.all(select_options)
    @nb_reviews = @reviews.size

    if @output_mode == "xml"
      render(:xml => Rcollection.new(@current_user.rpx_username, "xml output #{Time.now}", @reviews) )
    else
      # index.html.erb
    end


  end


  # get /reviews/new/:knowledge_id/:product_id
  def new
    # a brand new review for a given product
    @product = Product.first(:id => params[:product_id])
    user = get_logged_user
    @review = Review.new(:knowledge_idurl => @current_knowledge.idurl,
                         :knowledge_id => @current_knowledge.id,
                         :author => user.rpx_name,
                         :source => user.rpx_name,
                         :user => user,
                         :category => "expert",
                         :written_at => Date.today,
                         :reputation => 1,
                         :min_rating => 1,
                         :max_rating => 5)
  end

  # this is a rjs
  def add_product_2_review
    review = Review.find(params[:id])
    product = Product.find(params[:product_id])
    review.product_ids << product.id
    review.product_idurls << product.idurl
    review.save
    render :update do |page|
      page.replace("products_4_review",
         :partial => "/reviews/products_4_review",
         :locals => { :review => review } )
    end
  end

  # this is a rjs
  def delete_product_2_review
    review = Review.find(params[:id])
    product = Product.find(params[:product_id])
    review.product_ids.delete(product.id)
    review.product_idurls.delete(product.idurl) 
    review.save
    render :update do |page|
      page.replace("products_4_review",
         :partial => "/reviews/products_4_review",
         :locals => { :review => review } )
    end
  end


  # get /reviews/edit/:review_id
  def edit
    @review = Review.find(params[:id])
  end

  # post /reviews/create
  def create
    # this is a new review
    product = Product.find(params[:id])
    raise "no product #{params[:id].inspect} #{params.inspect}" unless product

    @review = Inpaper.new(params[:review])
    @review.written_at = params[:written_at].to_date    
    @review.user = get_logged_user
    @review.product_idurls = [product.idurl]
    @review.product_ids = [product.id]
    @review.knowledge_id = @current_knowledge.id
    @review.knowledge_idurl = @current_knowledge.idurl

    if @review.save
      flash[:notice] = "Review sucessufuly created"
      redirect_to  "/reviews/show/#{@review.id}"
    else
      flash[:notice] = "ERROR Review was not created"
      render(:action => "new")
    end
  end

  # post /reviews/update/id
  def update
    @review = Review.find(params[:id])
    @review.update_attributes(params[:review])
    
    @review.written_at = params[:written_at].to_date
    
    if @review.save
      flash[:notice] = "Review sucessufuly updated"
      redirect_to  "/reviews/show/#{@review.id}"
    else
      flash[:notice] = "ERROR Review was not upodated"
      render(:action => "edit")
    end
  end

  def split_in_paragraphs
    review = Review.find(params[:id])
    review.split_in_paragraphs(params[:mode])
    redirect_to  "/edit_review/#{review.id}"
  end

  # return a set of statistic for this knowledge base
  def statistics
    # sort the product by brand then label
    product_brands = @current_knowledge.products.collect do |p|
      b = p.get_value("brand")
      b = b.first if b
      b ||= ""
      [p, b] 
    end
    product_brands.sort! do |pb1, pb2|
      x = (pb1.last <=> pb2.last)
      x == 0 ? pb1.first.label <=> pb2.first.label : x
    end
    @products = product_brands.collect(&:first)
    @hash_product_opinions = Opinion.all().inject({}) do |h, opinion|
      opinion.product_ids.each do |opinion_product_id|
        (h[opinion_product_id] ||= []) << opinion
      end
      h
    end

    @hash_product_reviews = Review.all(:knowledge_id => @current_knowledge.id).inject({}) do |h, r|
      r.product_ids.each { |pid| ((h[pid] ||= {})[r.category] ||= []) << r }
      h
    end
    
    @opinions_classes = [Rating, Tip, Ranking, Comparator, Neutral]
    @review_categories = ["amazon", "expert"]

    @overall_dimension_id = @current_knowledge.dimension_root.id
  end


end

