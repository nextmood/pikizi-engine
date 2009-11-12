class QuizzesController < ApplicationController

  # GET /quizzes/knowledge_idurl
  def index
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
  end

  # GET /quizzes/knowledge_idurl/quizze_idurl
  def show
    knowledge_idurl = params[:knowledge_idurl]
    quizze_idurl = params[:quizze_idurl]
    @knowledge = Knowledge.get_from_idurl(knowledge_idurl)
    @quizze = @knowledge.get_quizze_by_idurl(quizze_idurl)
  end

  # executing a quizze instance for the current user
  # GET /myquizze/knowledge_idurl/quizze_idurl
  # GET /myquizze/knowledge_idurl
  def myquizze
    @knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
    @quizze = @knowledge.get_quizze_by_idurl(quizze_idurl = params[:quizze_idurl] || knowledge_idurl)
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
  end

  # POST /quizzes/knowledge.idurl/quizze.idurl/edit
  # editing a quizze (list of questions and products)
  def edit
    knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
    quizze = knowledge.get_quizze_by_idurl(quizze_idurl = params[:quizze_idurl])
    quizze.question_idurls = params[:select_question_idurls]
    quizze.product_idurls = params[:select_product_idurls]
    quizze.save
    redirect_to("/quizzes/#{knowledge_idurl}/#{quizze_idurl}")
  end
  
end
