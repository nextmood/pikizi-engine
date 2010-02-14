
class ReviewsController < ApplicationController


  # GET /reviews/knowledge_idurl
  def index
    get_product_selected(params)
  end


  # GET /reviews/:review_id
  def show
    puts Root.duration {
    @review = Review.find(params[:id])
    @knowledge = Knowledge.load(@review.knowledge_idurl)
    }
  end

  # this is a rjs
  def open_opinion_editor
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    render :update do |page|
      page.replace_html("p#{ranking_number}",
         :partial => "/reviews/opinion_editor_bis",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => ranking_number } )
    end
  end

  # this is a rjs
  def add_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    type_opinion = params[:type_opinion]
    render :update do |page|
      page.replace_html("opinion_#{ranking_number}_form",
         :partial => "/reviews/opinion_editor",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => ranking_number, :type_opinion => type_opinion } )
    end
  end

  # this is a rjs
  def feature_filter
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    puts "feature found=#{feature.inspect}"
    render :update do |page|
      page.replace_html("filter_feature",
         :partial => "/reviews/filter_feature",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => ranking_number, :feature => feature } )
    end
  end

  # this is a rjs  
  def delete_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    paragraph_ranking_number = Integer(params[:ranking_number])
    opinion = Opinion.find(params[:opinion_id])
    opinion.destroy
    render :update do |page|
      page.replace_html("p#{paragraph_ranking_number}",
         :partial => "/reviews/opinion_editor_bis",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => paragraph_ranking_number } )
    end
    
  end

  # this a form submit (post)
  # and a rjs
  def create_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    paragraph_ranking_number = Integer(params[:ranking_number])
    base_options = { :review_id => review.id,
                     :user_id => (get_logged_user ? get_logged_user.id : nil),
                     :feature_rating_idurl => params[:dimension_rating],
                     :paragraph_ranking_number => paragraph_ranking_number }

    opinion = case type_opinion = params[:type_opinion]

      when "tip"
        tip_usage = params[:tip_usage]
        tip_intensity_or_neutral = params[:tip_intensity_or_neutral]
        intensity = (tip_intensity_or_neutral == "neutral" ? 0.0 : Float(tip_intensity_or_neutral))
        Opinion::Tip.create(base_options.clone.merge(
                :label => "#{tip_intensity_or_neutral}... for #{tip_usage.inspect}",
                :intensity => intensity,
                :is_neutral => (tip_intensity_or_neutral == "neutral"),
                :usage => tip_usage  ))

      when "comparator_product"
        comparator_operator = params[:comparator_operator]
        comparator_product = params[:comparator_product]
        Opinion::Comparator.create(base_options.clone.merge(
                :label => "product #{comparator_operator} #{comparator_product}",
                :operator_type => comparator_operator,
                :predicate =>  "productIs(:any => [#{comparator_product}])" ))


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
      page.replace_html("p#{paragraph_ranking_number}",
         :partial => "/reviews/opinion_editor_bis",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => paragraph_ranking_number } )
    end
  end

  # this is a rjs
  def edit_paragraph
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    paragraph = review.get_paragraph_by_ranking_number(ranking_number)
    raise "no paragraph with ranking=#{ranking_number.inspect}" unless paragraph

    render :update do |page|
      page.replace_html("paragraph_#{ranking_number}",
         :partial => "/reviews/paragraph_editor",
         :locals => { :review => review, :knowledge => knowledge, :paragraph => paragraph } )
    end
  end

  # this is a rjs
  def edit_paragraph_cancel
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    paragraph = review.get_paragraph_by_ranking_number(ranking_number)
    raise "no paragraph with ranking=#{ranking_number.inspect}" unless paragraph
    render :update do |page|
      page.replace_html("paragraph_#{ranking_number}", :partial => "/reviews/paragraph", :locals => { :review => review, :paragraph => paragraph })
    end
  end

  # get /cut_paragraph/:review_id/:ranking_number/:caret_position
  def cut_paragraph
    review = Review.find(params[:review_id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = Integer(params[:ranking_number])
    paragraph = review.get_paragraph_by_ranking_number(ranking_number)
    raise "no paragraph with ranking=#{ranking_number.inspect}" unless paragraph
    review.cut_paragraph_at(paragraph, Integer(params[:caret_position]))
    redirect_to "/reviews/show/#{review.id}"
  end



end
