
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


end
