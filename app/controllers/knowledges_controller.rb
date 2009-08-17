
class KnowledgesController < ApplicationController
  # GET /knowledges
  # GET /knowledges.xml
  def index
    @knowledges = Knowledge.find(:all, :order => "updated_at DESC")

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @knowledges }
    end
  end


  def show_by_key
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
    # retrieve the product, if the product doesn't exist create one
    @product = Pikizi::Product.get_from_cache(params[:product_key]) if params[:product_key]
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
    @user = get_or_create_pkz_user
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

  # GET /backgrounds/:knowledge_key/[:feature_key || all]
  # GET /backgrounds/:knowledge_key/[:feature_key || all]/product_key

  def backgrounds
    @knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])

    # retrieve the product
    @product = Pikizi::Product.get_from_cache(params[:product_key]) if params[:product_key]
    @backgrounds = []
  end


  # GET /knowledges/update_indexes
  # update the knowledge database
  def update_indexes
    Knowledge.delete_all
    Pikizi::Knowledge.xml_keys.each do |knowledge_key|
      pkz_knowledge = Pikizi::Knowledge.create_from_xml(knowledge_key)
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
