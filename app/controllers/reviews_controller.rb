
class ReviewsController < ApplicationController





  # GET /reviews/:review_id
  def show
    puts "id=" << params[:id]
    @review = Review.find(params[:id])
    @knowledge = @review.product.knowledge
    @paragraph_selected_number = params[:p] ? Integer(params[:p]) : nil

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render(:xml => @review ) }
    end
  end

  # this is a rjs
  def open_opinion_editor
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_editor_bis",
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
         :partial => "/reviews/opinion_editor",
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
    review = Review.find(params[:id])
    knowledge = Knowledge.load_db(review.knowledge_idurl)
    paragraph = Paragraph.find(params[:paragraph_id])
    opinion = Opinion.find(params[:opinion_id])
    opinion.destroy
    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_editor_bis",
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
                     :paragraph => paragraph }

    opinion = case type_opinion = params[:type_opinion]

      when "tip"
        tip_usage = params[:tip_usage]
        tip_intensity_or_mixed = params[:tip_intensity_or_mixed]
        intensity = (tip_intensity_or_mixed == "mixed" ? 0.0 : Float(tip_intensity_or_mixed))
        Opinion::Tip.create(base_options.clone.merge(
                :label => "#{tip_intensity_or_mixed}... for #{tip_usage.inspect}",
                :intensity => intensity,
                :is_mixed => (tip_intensity_or_mixed == "mixed"),
                :usage => tip_usage  ))

      when "comparator_product"
        comparator_operator = params[:comparator_operator]
        comparator_product = params[:comparator_product]
        Opinion::Comparator.create(base_options.clone.merge(
                :label => "product #{comparator_operator} #{comparator_product}",
                :operator_type => comparator_operator,
                :predicate =>  "productIs(:any => [\"#{comparator_product}\"])" ))


      when "comparator_feature"
        comparator_operator = params[:comparator_operator]
        comparator_feature = params[:comparator_feature]
        feature_filter_datas = params[:feature_filter_datas]
        predicate = "featureIs(:#{comparator_feature}, :any => #{feature_filter_datas.inspect})"
        Opinion::Comparator.create(base_options.clone.merge(
                :label => "feature #{comparator_feature} of product #{comparator_operator} #{predicate}",
                :operator_type => comparator_operator,
                :predicate =>  predicate ))

      when "rating"
        rating = params[:rating],
        min_rating = params[:rating_min],
        max_rating = params[:rating_max]
        Opinion::Rating.create(base_options.clone.merge(
                :label => "rated #{rating} (min=#{min_rating}, max=#{max_rating})",
                :rating => rating,
                :min_rating => min_rating,
                :max_rating => max_rating ))

      when "feature_related"
        feature_related = params[:feature_related]
        Opinion::FeatureRelated.create(base_options.clone.merge(
                :label => "related to feature #{feature_related}",
                :feature_related_idurl => feature_related ))

      else
        raise "unknown type_opinion #{params[:type_opinion]}"
    end

    render :update do |page|
      page.replace_html("p#{paragraph.id}",
         :partial => "/reviews/opinion_editor_bis",
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
    product = Product.first(:id => params[:product_id])
    user = get_logged_user
    @review = Review.new(:knowledge_idurl => @knowledge.idurl,
                         :knowledge_id => @knowledge.id,
                         :product => product,
                         :product_idurl => product.idurl,
                         :author => user.rpx_name,
                         :source => user.rpx_name,
                         :user => user,
                         :category => "expert",
                         :written_at => Time.now,
                         :reputation => 1,
                         :min_rating => 1,
                         :max_rating => 5)
  end

  # get /reviews/edit/:review_id
  def edit
    @review = Review.find(params[:id])
    @knowledge = @review.knowledge
  end

  # post /reviews/create
  def create
    # this is a new review
    product = Product.find(params[:review][:product_id])
    raise "no product for key=#{params[:review][:product_id].inspect}" unless product

    @knowledge = Knowledge.first(:idurl => params[:review][:knowledge_idurl])
    raise "no knowledge for key=#{params[:review][:knowledge_idurl].inspect}" unless @knowledge

    @review = Review::Inpaper.new(params[:review])
    @review.written_at = params[:written_at].to_date    
    @review.user = get_logged_user
    @review.product_idurl = product.idurl
    @review.product_id = product.id

    if @review.save
      flash[:notice] = "Review sucessufuly created"
      redirect_to  "/reviews/show/#{@review.id}"
    else
      flash[:notice] = "ERROR Review was not created"
      render(:action => "new")
    end
  end

  # post /reviews/update
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

