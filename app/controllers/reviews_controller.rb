
class ReviewsController < ApplicationController

  require 'opinion'
  
  # GET /reviews/:review_id
  def show
    puts "id=" << params[:id]
    @review = Review.find(params[:id])
    @products = @review.products
    @knowledge = @products.first.knowledge
    @opinion_selected = Opinion.find(params[:opinion_id]) if params[:opinion_id]
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render(:xml => @review ) }
    end
  end

  # this is a rjs
  def open_opinion_creator
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_list",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  # this is a rjs
  def add_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    type_opinion = params[:type_opinion]
    render :update do |page|
      page.replace_html("opinion_#{paragraph.id}_form",
         :partial => "/reviews/opinion_creator",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph, :type_opinion => type_opinion } )
    end
  end

  # this is a rjs
  def feature_filter
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    puts "feature found=#{feature.inspect}"
    render :update do |page|
      page.replace_html("filter_feature",
         :partial => "/reviews/filter_feature",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph, :feature => feature } )
    end
  end

  # this is a rjs
  def delete_opinion
    opinion = Opinion.find(params[:id])
    paragraph = opinion.paragraph
    review = opinion.review
    knowledge = review.knowledge    
    opinion.destroy
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_list",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end

  end

  # this is a rjs
  def edit_opinion
    opinion = Opinion.find(params[:id])
    paragraph = opinion.paragraph
    review = opinion.review
    knowledge = review.knowledge
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_editor",
         :locals => { :opinion => opinion, :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  def edit_opinion_cancel
    opinion = Opinion.find(params[:id])
    paragraph = opinion.paragraph
    review = opinion.review
    knowledge = review.knowledge
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_list",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  # this a form submit (post)
  # and a rjs
  def create_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    base_options = { :review_id => review.id,
                     :user_id => (get_logged_user ? get_logged_user.id : nil),
                     :feature_rating_idurl => params[:dimension_rating],
                     :value_oriented => params[:value_oriented],
                     :paragraph => paragraph }

    # left operator (the product concerned)
    base_options[:product_ids] = case params[:products_mask]
      when "" then []
      when "all_in_review" then review.product_ids
      else
        l = params[:products_mask].split('-').collect { |pid| Mongo::ObjectID.from_string(pid) }
        Product.find(l).collect(&:id)
    end

    opinion = case type_opinion = params[:type_opinion]

      when "tip"
        usage = params[:usage]
        intensity_symbol = params[:intensity_symbol]
        Tip.create(base_options.clone.merge(
                :label => "#{intensity_symbol}... for #{usage.inspect}",
                :intensity_symbol => intensity_symbol,
                :usage => usage,
                :extract => params[:extract]  ))

      when "comparator_product"
        comparator_operator = params[:comparator_operator]
        comparator_product = params[:comparator_product]
        Comparator.create(base_options.clone.merge(
                :label => "product #{comparator_operator} #{comparator_product}",
                :operator_type => comparator_operator,
                :predicate =>  "productIs(:#{comparator_product})",
                :usage => params[:usage],
                :extract => params[:extract] ))


      when "comparator_feature"
        comparator_operator = params[:comparator_operator]
        comparator_feature = params[:comparator_feature]
        feature_filter_datas = params[:feature_filter_datas]
        predicate = "featureIs(:#{comparator_feature}, :any => #{feature_filter_datas.inspect})"
        Comparator.create(base_options.clone.merge(
                :label => "feature #{comparator_feature} of product #{comparator_operator} #{predicate}",
                :operator_type => comparator_operator,
                :predicate =>  predicate,
                :usage => params[:usage],
                :extract => params[:extract] ))

      when "rating"
        rating = params[:rating].to_f
        min_rating = params[:rating_min].to_f
        max_rating = params[:rating_max].to_f
        Rating.create(base_options.clone.merge(
                :label => "rated #{rating} (min=#{min_rating}, max=#{max_rating})",
                :rating => rating,
                :min_rating => min_rating,
                :max_rating => max_rating,
                :usage => params[:usage],
                :extract => params[:extract] ))

      when "feature_related"
        feature_related = params[:feature_related]
        FeatureRelated.create(base_options.clone.merge(
                :label => "related to feature #{feature_related}",
                :feature_related_idurl => feature_related ))

      else
        raise "unknown type_opinion #{params[:type_opinion]}"
    end

    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_list",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  def update_opinion
    opinion = Opinion.find(params[:id])
    paragraph = opinion.paragraph
    review = opinion.review
    knowledge = review.knowledge
    new_values = params[[:tip, :comparator, :feature_related, :rating].detect { |x| params[x] }]
    opinion.update_attributes(new_values)
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_list",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  # this is a rjs
  def edit_paragraph
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    raise "no paragraph with id=#{params[:paragraph_id]}" unless paragraph

    render :update do |page|
      page.replace_html("paragraph_#{paragraph.id}",
         :partial => "/reviews/paragraph_editor",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  # this is a rjs
  def edit_paragraph_cancel
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    raise "no paragraph with id=#{params[:paragraph_id]}" unless paragraph
    render :update do |page|
      page.replace_html("paragraph_#{paragraph.id}", :partial => "/reviews/paragraph", :locals => { :review => review, :paragraph => paragraph })
    end
  end

  # get /cut_paragraph/:review_id/:paragraph_id/:caret_position
  def cut_paragraph
    review = Review.find(params[:review_id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    raise "no paragraph with id=#{params[:paragraph_id]}" unless paragraph
    review.cut_paragraph_at(paragraph, Integer(params[:caret_position]))
    redirect_to "/reviews/show/#{review.id}"
  end


  def split_in_paragraphs
    review = Review.find(params[:id])
    review.split_in_paragraphs(params[:mode])
    redirect_to "/reviews/show/#{review.id}"
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

    @review = Review::Inpaper.new(params[:review])
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

end

