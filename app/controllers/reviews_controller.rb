
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
    ranking_number = params[:ranking_number]
    render :update do |page|
      page.replace_html("p#{ranking_number}",
         :partial => "/reviews/opinion_editor_bis",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => ranking_number, :ranking_number => ranking_number } )
    end
  end

  # this is a rjs
  def add_opinion
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = params[:ranking_number]
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
    ranking_number = params[:ranking_number]
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    puts "feature found=#{feature.inspect}"
    render :update do |page|
      page.replace_html("filter_feature_#{ranking_number}",
         :partial => "/reviews/filter_feature",
         :locals => { :review => review, :knowledge => knowledge, :ranking_number => ranking_number, :feature => feature } )
    end
  end

  def create_opinion

  end

  # this is a rjs
  def edit_paragraph
    review = Review.find(params[:id])
    knowledge = Knowledge.load(review.knowledge_idurl)
    ranking_number = params[:ranking_number]
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
    ranking_number = params[:ranking_number]
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
    ranking_number = params[:ranking_number]
    paragraph = review.get_paragraph_by_ranking_number(ranking_number)
    raise "no paragraph with ranking=#{ranking_number.inspect}" unless paragraph
    review.cut_paragraph_at(paragraph, Integer(params[:caret_position]))
    redirect_to "/reviews/show/#{review.id}"
  end



end
