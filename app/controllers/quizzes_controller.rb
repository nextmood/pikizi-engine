class QuizzesController < ApplicationController

  # GET /quizzes/knowledge_idurl
  def index
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
  end


  # GET /quizzes/knowledge_idurl/[quizze_idurl]
  def show
    knowledge_idurl = params[:knowledge_idurl]
    quizze_idurl = params[:quizze_idurl]
    @knowledge = Knowledge.get_from_idurl(knowledge_idurl)
    @quizze = @knowledge.quizzes.detect {|q| q.idurl == quizze_idurl }
    @current_user = get_logged_user
    @quizze_instance = @current_user.get_quizze_instance(@quizze)
  end

end
