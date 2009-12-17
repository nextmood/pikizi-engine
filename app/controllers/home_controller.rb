
class HomeController < ApplicationController

  # GET /:knowledge_idurl
  # return the available quizzes for this model
  def index()
    if @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    else
      redirect_to("/")
    end
  end

  # GET /:knowledge_idurl/myquiz/:quizze_idurl
  # asking the next question for a given quiz
  def myquiz()
    @knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
    @quizze = @knowledge.get_quizze_by_idurl(params[:quizze_idurl])
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
  end

  # GET /:knowledge_idurl/myresults/:quizze_idurl
  def myresults()
    @knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
    @quizze = @knowledge.get_quizze_by_idurl(params[:quizze_idurl])
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
    @sorted_affinities = @quizze_instance.sorted_affinities
    @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@knowledge, @sorted_affinities)
  end

  # POST /record_answer
  def record_answer
     knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
     quizze = Quizze.get_from_idurl(quizze_idurl = params[:quizze_idurl])
     question = Question.get_from_idurl(question_idurl = params[:question_idurl])
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     redirect_to("/#{knowledge_idurl}/myquiz/#{quizze_idurl}")
  end


end
