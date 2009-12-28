class QuizzesController < ApplicationController

  # GET /quizzes/knowledge_idurl
  def index
    @knowledge = Knowledge.load(params[:knowledge_idurl])
  end

  # GET /quizzes/knowledge_idurl/quizze_idurl
  def show
    knowledge_idurl = params[:knowledge_idurl]
    quizze_idurl = params[:quizze_idurl]
    @knowledge = Knowledge.load(knowledge_idurl)
    @quizze = Quizze.load(quizze_idurl)
  end

  # executing a quizze instance for the current user
  # GET /myquizze/knowledge_idurl/quizze_idurl
  # GET /myquizze/knowledge_idurl
  def myquizze
    @knowledge = Knowledge.load(knowledge_idurl = params[:knowledge_idurl])
    @quizze = Quizze.load(params[:quizze_idurl] || knowledge_idurl)
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
  end

  # show details results of a quizze instance
  # GET /myquizze_results/knowledge_idurl/quizze_idurl
  # GET /myquizze_results/knowledge_idurl
  def myquizze_results
    @knowledge = Knowledge.load(params[:knowledge_idurl])
    @quizze = Quizze.load(params[:quizze_idurl])
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
    @sorted_affinities = @quizze_instance.sorted_affinities
    @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@knowledge, @sorted_affinities)

    #@results_details = @quizze_instance.results_details(@knowledge)
    #@rankings_and_products = .collect { |affinity| [affinity.ranking, @knowledge.get_product_by_idurl(affinity.product_idurl)] }
  end


  # POST /quizzes/knowledge.idurl/quizze.idurl/edit
  # editing a quizze (list of questions and products)
  def edit
    knowledge = Knowledge.load(knowledge_idurl = params[:knowledge_idurl])
    quizze = Quizze.load(quizze_idurl = params[:quizze_idurl])
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
