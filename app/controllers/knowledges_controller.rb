
class KnowledgesController < ApplicationController

  # layout "minimal", :only => :quiz


  # GET /knowledges
  # GET /knowledges.xml
  def index
    knowledge = Knowledge.find(:all, :order => "updated_at DESC").first
    redirect_to("/show/#{knowledge.key}")
  end


  def show_by_key
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    # retrieve the product, if the product doesn't exist create one
    @product = Pikizi::Product.get_from_cache(params[:product_key]) if params[:product_key]
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @knowledges.generate_xml }
    end
  end

  def distance
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    @feature = params[:feature_key] ? @knowledge.get_feature_by_key(params[:feature_key]) : @knowledge
    @products = @knowledge.products.sort! { |p1, p2| p1.key <=> p2.key }
  end

  def matrix
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    @products = @knowledge.products
    @features = @knowledge.each_feature_collect(true) { |feature| feature }.flatten
  end

  def edit_by_key
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
  end

  def show_questions
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    @products = @knowledge.products
  end

  def show_question
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    @question = @knowledge.get_question_from_key(params[:question_key])
    @products = @knowledge.products
  end

  # GET /quiz/knowledge_key/[quiz_key]
  def quiz
    knowledge_key = params[:knowledge_key]
    quiz_key = (params[:quiz_key] || knowledge_key)
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])

    @quiz = @knowledge.quizzes.detect {|q| q.key == quiz_key }
    @user = get_logged_ar_user.pkz_user
    @quiz_instance = @user.get_quiz_instance(@quiz)

    respond_to do |format|
      if @quiz
        format.html # quiz.html.erb
        format.xml  { head :ok }
      else
        flash[:error] = 'Unknown quiz.'
        format.html { render :action => "show_by_key" }
        format.xml  { render :xml => @knowledge.errors, :status => :unprocessable_entity }
      end
    end

  end

  # GET /medias/:knowledge_key/:selector/parameters...
  #
  # GET /medias/:knowledge_key/model/[:feature_key]
  # GET /medias/:knowledge_key/product/:product_key/[:feature_key]
  # GET /medias/:knowledge_key/question/:question_key/[:choice_key]
  #
  def medias
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    case @selector = params[:selector]
      when :model
        @feature = @knowledge.get_feature_by_key(params[:feature_key] || params[:knowledge_key])
        @medias = @feature.get_backgrounds
      when :product
        @feature = @knowledge.get_feature_by_key(params[:feature_key] || params[:knowledge_key])
        @product = Pikizi::Product.get_from_cache(params[:product_key])
        @medias = @feature.get_backgrounds(@product)
      when :question
        @question = @knowledge.get_question_from_key(params[:question_key])
        if params[:choice_key]
          @choice = @question.get_choice_from_key(params[:choice_key])
          @medias = @choice.get_backgrounds
        else
          @medias = @question.get_backgrounds
        end
      else
      raise "unknown selector #{params[:selector]}"
    end
  end


  # GET /aggregations/:knowledge_key/model/:product_key/[:feature_key]
  def aggregations
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    @feature = @knowledge.get_feature_by_key(params[:feature_key] || params[:knowledge_key])
    @product = Pikizi::Product.get_from_cache(params[:product_key])
    @aggregations = @knowledge.get_aggregations(@product)
  end

  # GET /knowledges/update_indexes
  # update the knowledge database
  def update_indexes
    Knowledge.delete_all
    Pikizi::Knowledge.xml_keys.each do |knowledge_key|
      pkz_knowledge = Pikizi::Knowledge.get_from_cache(knowledge_key)
      knowledge = Knowledge.create(
              :key => knowledge_key,
              :label => pkz_knowledge.label,
              :nb_features => pkz_knowledge.nb_features,
              :nb_products => pkz_knowledge.nb_products,
              :nb_questions => pkz_knowledge.nb_questions,
              :nb_quizzes => pkz_knowledge.nb_quizzes)

    end  
    redirect_to("/knowledges")
  end

end
