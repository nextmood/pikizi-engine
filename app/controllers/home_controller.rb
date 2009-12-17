
class HomeController < ApplicationController

  # GET /quizzes
  # return all available quizzes for all knowledges
  def quizzes
    @knowledge = Knowledge.find(:first)
  end

  # GET /start_quiz/:quizze_idurl
  # create a new quiz for the current user
  def start_quiz
    quizze = Quizze.find_by_idurl(params[:quizze_idurl])
    get_logged_user.create_quizze_instance(quizze)
    redirect_to "/my_quiz"
  end

  # GET /my_quiz
  # asking the next question for a given quiz
  def my_quiz
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @knowledge = @quizze.knowledge
    else
      redirect_to("/quizzes") # select a quizz first !
    end
  end

  # GET /my_results
  def my_results
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @knowledge = @quizze.knowledge
      @sorted_affinities = @quizze_instance.sorted_affinities
      @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@knowledge, @sorted_affinities)
    else
      redirect_to("/quizzes") # select a quizz first !
    end    
  end

  # POST /record_my_answer
  def record_my_answer
     knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
     quizze = Quizze.get_from_idurl(quizze_idurl = params[:quizze_idurl])
     question = Question.get_from_idurl(question_idurl = params[:question_idurl])
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     redirect_to("/my_quiz")
  end


end
