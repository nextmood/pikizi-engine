
class ReviewsController < ApplicationController

  require 'opinion'

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
    @products4review = @review.products

    respond_to do |format|
      format.html # show.html.erb
    end
  end


  # get /reviews/new/:knowledge_id/:product_id
  def new
    # a brand new review for a given product
    @knowledge = Knowledge.first(:id => params[:id])
    @product = Product.first(:id => params[:product_id])
    user = get_logged_user
    @review = Review.new(:knowledge_idurl => @knowledge.idurl,
                         :knowledge_id => @knowledge.id,
                         :author => user.rpx_name,
                         :source => user.rpx_name,
                         :user => user,
                         :category => "expert",
                         :written_at => Time.now,
                         :reputation => 1,
                         :min_rating => 1,
                         :max_rating => 5)
  end

  # this is a rjs
  def add_product_2_review
    review = Review.find(params[:id])
    knowledge = review.knowledge
    product = Product.find(params[:product_id])
    review.product_ids << product.id
    review.product_idurls << product.idurl
    review.save
    render :update do |page|
      page.replace("products_4_review",
         :partial => "/reviews/products_4_review",
         :locals => { :review => review, :knowledge => knowledge } )
    end
  end

  # this is a rjs
  def delete_product_2_review
    review = Review.find(params[:id])
    knowledge = review.knowledge
    product = Product.find(params[:product_id])
    review.product_ids.delete(product.id)
    review.product_idurls.delete(product.idurl) 
    review.save
    render :update do |page|
      page.replace("products_4_review",
         :partial => "/reviews/products_4_review",
         :locals => { :review => review, :knowledge => knowledge } )
    end
  end


  # get /reviews/edit/:review_id
  def edit
    @review = Review.find(params[:id])
    @knowledge = @review.knowledge
    raise "error no knowledge #{@review.knowledge_id} #{@review.knowledge_idurl}" unless @review.knowledge.id
  end

  # post /reviews/create
  def create
    # this is a new review
    product = Product.find(params[:product_id])
    raise "no product #{params[:product_id].inspect} #{params.inspect}" unless product
    @knowledge = Knowledge.first(:idurl => params[:review][:knowledge_idurl])
    raise "no knowledge for key=#{params[:review][:knowledge_idurl].inspect}" unless @knowledge

    @review = Inpaper.new(params[:review])
    @review.written_at = params[:written_at].to_date    
    @review.user = get_logged_user
    @review.product_idurls = [product.idurl]
    @review.product_ids = [product.id]
    @review.knowledge_id = @knowledge.id
    @review.knowledge_idurl = @knowledge.idurl
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
    @knowledge = @review.knowledge
    
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

