class QuizzesController < ApplicationController

  # GET /quizzes/knowledge_idurl
  def index
    @knowledge = Knowledge.load_db(params[:knowledge_idurl])
  end

  # GET /quizzes/knowledge_idurl/quizze_idurl
  def show
    knowledge_idurl = params[:knowledge_idurl]
    quizze_idurl = params[:quizze_idurl]
    @knowledge = Knowledge.load_db(knowledge_idurl)
    @quizze = Quizze.load_db(quizze_idurl)
  end

  # executing a quizze instance for the current user
  # GET /myquizze/knowledge_idurl/quizze_idurl
  # GET /myquizze/knowledge_idurl
  def myquizze
    @knowledge = Knowledge.load_db(knowledge_idurl = params[:knowledge_idurl])
    @quizze = Quizze.load_db(params[:quizze_idurl] || knowledge_idurl)
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
  end

  # show details results of a quizze instance
  # GET /myquizze_results
  def myquizze_results
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @knowledge = @quizze.get_knowledge
      @sorted_affinities = @quizze_instance.sorted_affinities
      @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@knowledge, @sorted_affinities)
    else
      redirect_to("/quizzes") # select a quizz first !
    end
  end


  # POST /quizzes/knowledge.idurl/quizze.idurl/edit
  # editing a quizze (list of questions and products)
  def edit
    knowledge = Knowledge.load_db(knowledge_idurl = params[:knowledge_idurl])
    quizze = Quizze.load_db(quizze_idurl = params[:quizze_idurl])
    quizze.question_idurls = params[:select_question_idurls]
    quizze.product_idurls = params[:select_product_idurls]
    quizze.save
    redirect_to("/quizzes/#{knowledge_idurl}/#{quizze_idurl}")
  end

  # this is rjs for the feedback
  def toggle_feedback
    product_idurl params[:product_idurl]
    next_feedback_code = Integer(params[:next_feedback_code])
    dom_id = "feedback_#{product_idurl}"
    render :update do |page|
      page.replace_html(dom_id, :partial => "/quizzes/feedback",
        :locals => {:product_idurl => product_idurl, :feedback_code => next_feedback_code})
    end
  end
  
end
