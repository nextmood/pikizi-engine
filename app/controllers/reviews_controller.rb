require 'opinion'
require 'paginator'


class ReviewsController < ApplicationController


  # api for eric
  def eric
    @reviews = @current_knowledge.reviews
    # @reviews = @reviews[0..10]
    respond_to do |format|
      format.html # eric.html.erb
      format.xml  { render(:xml => Review ) }
    end
  end

  # GET /reviews/:review_id
  def show
    @review = Review.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def recompute_all_states
    Review.all.each do |review| review.update_status(true) end
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
    review.update_status(true)
    flash[:notice] = "#{nb_opinions_moved} opinion(s) moved for #{nb_opinions} opinions total"
    redirect_to "/reviews/edit/#{review.id}"
  end

  # list all reviews for current knowledge
  def index
    @nb_reviews_per_page = 40
    @source_categories = params[:source_categories]
    @source_categories ||= Review.categories.collect { |category_name, weight| category_name }
    @state_names = params[:state_names]
    @state_names ||= Review.list_states

    select_options = { :category => @source_categories, :state => @state_names }
    @nb_reviews = Review.count(select_options)
    @pager = Paginator.new(@nb_reviews, @nb_reviews_per_page) do |offset, per_page|
      Review.all({:offset => offset, :limit => per_page, :order => 'written_at desc'}.merge(select_options))
    end
    @reviews = @pager.page(params[:page])
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
    puts "***************** #{@review.product_ids.inspect}"

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

end

