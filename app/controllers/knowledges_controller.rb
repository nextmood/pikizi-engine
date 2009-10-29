
class KnowledgesController < ApplicationController

  # layout "minimal", :only => :quiz


  # GET /knowledges
  # GET /knowledges.xml
  # return the most recent knowledge
  def index
    knowledge = Knowledge.find(:all, :order => "updated_at DESC").first
    puts "size=#{ Knowledge.find(:all).size}  knowledge=#{knowledge.inspect} "
    redirect_to("/matrix/#{knowledge.idurl}")
  end

  def distance
    @knowledge, @products, @products_selected = get_products_selected(params)
    @feature = params[:feature_idurl] ? @knowledge.get_feature_by_idurl(params[:feature_idurl]) : @knowledge
  end

  def matrix
    @knowledge, @products, @products_selected = get_products_selected(params)
    @features = @knowledge.each_feature_collect { |feature| feature }.flatten
  end

  def get_products_selected(params)
    knowledge =  Knowledge.get_from_idurl(params[:knowledge_idurl])
    products = knowledge.products.sort! { |p1, p2| p1.idurl <=> p2.idurl }
    pidurls_selected = params[:select_product_idurls]
    pidurls_selected ||= session[:pidurls_selected]
    pidurls_selected ||= products.collect(&:idurl).first(3)
    session[:pidurls_selected] = pidurls_selected
    [knowledge, products, products.select { |p| pidurls_selected.include?(p.idurl) }]
  end

  def edit_by_idurl
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
  end

  def show_questions
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @products = @knowledge.products
  end

  def show_question
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @question = @knowledge.get_question_by_idurl(params[:question_idurl])
    @hash_product_proba = @question.enumerator
    @products = @knowledge.products
  end

  # GET /quiz/knowledge_idurl/[quiz_idurl]
  def quiz
    knowledge_idurl = params[:knowledge_idurl]
    quiz_idurl = (params[:quiz_idurl] || knowledge_idurl)
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])

    @quiz = @knowledge.quizzes.detect {|q| q.idurl == quiz_idurl }
    @user = get_logged_ar_user.pkz_user
    @quiz_instance = @user.get_quiz_instance(@quiz)

    respond_to do |format|
      if @quiz
        format.html # quiz.html.erb
        format.xml  { head :ok }
      else
        flash[:error] = 'Unknown quiz.'
        format.html { render :action => "matrix" }
        format.xml  { render :xml => @knowledge.errors, :status => :unprocessable_entity }
      end
    end

  end

  # thsi is rjs
  def feature_value_edit
    knowledge =  Knowledge.get_from_idurl(params[:knowledge_idurl])
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    product =  Product.get_from_idurl(params[:product_idurl], knowledge)
    dom_id = "cell_#{feature.idurl}_#{product.idurl}"
    mode = params[:mode] # in "edit", "cancel"
    partial_name = "/knowledges/feature_value_#{ params[:mode] == 'cancel' ? 'show' : 'edit' }"
    render :update do |page|
      page.replace(dom_id, :partial => partial_name,
                  :locals => {:knowledge => knowledge, :feature => feature, :product => product})
    end
  end


  # thsi is rjs
  def feature_edit
    knowledge =  Knowledge.get_from_idurl(params[:knowledge_idurl])
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    dom_id = "cell_#{feature.idurl}"
    mode = params[:mode] # in "edit", "cancel"
    partial_name = "/knowledges/feature_#{ params[:mode] == 'cancel' ? 'show' : 'edit' }"
    render :update do |page|
      page.replace(dom_id, :partial => partial_name, 
                  :locals => { :knowledge => knowledge, :feature => feature, :tr_id => feature.dom_id })
    end
  end

  # GET /medias/:knowledge_idurl/:selector/parameters...
  #
  # GET /medias/:knowledge_idurl/model/[:feature_idurl]
  # GET /medias/:knowledge_idurl/product/:product_idurl/[:feature_idurl]
  # GET /medias/:knowledge_idurl/question/:question_idurl/[:choice_idurl]
  #
  def medias
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    case @selector = params[:selector]
      when :model
        @feature = @knowledge.get_feature_by_idurl(params[:feature_idurl] || params[:knowledge_idurl])
        @medias = @feature.get_backgrounds
      when :product
        @feature = @knowledge.get_feature_by_idurl(params[:feature_idurl] || params[:knowledge_idurl])
        @product = Product.get_from_idurl(params[:product_idurl])
        @medias = @feature.get_backgrounds(@product)
      when :question
        @question = @knowledge.get_question_by_idurl(params[:question_idurl])
        if params[:choice_idurl]
          @choice = @question.get_choice_from_idurl(params[:choice_idurl])
          @medias = @choice.get_backgrounds
        else
          @medias = @question.get_backgrounds
        end
      else
      raise "unknown selector #{params[:selector]}"
    end
  end


  # GET /aggregations/:knowledge_idurl/model/:product_idurl/[:feature_idurl]
  def aggregations
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @feature = @knowledge.get_feature_by_idurl(params[:feature_idurl] || params[:knowledge_idurl])
    @product = Product.get_from_idurl(params[:product_idurl])
    @aggregations = @knowledge.get_aggregations(@product)
  end


end
