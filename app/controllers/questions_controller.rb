
class QuestionsController < ApplicationController
  

  # GET /questions/knowledge_idurl
  def index
    get_products_selected # initialize @products and @products_selected
  end


  def update_weight
    question = Question.load_db(params[:question_idurl])
    question.weight +=  params[:delta]
    question.save
    redirect_to("/questions/#{params[:knowledge_idurl]}")
  end

  # GET /questions/knowledge_idurl/question_idurl
  def show
    get_products_selected  # initialize @products and @products_selected
    @question = @current_knowledge.get_question_by_idurl(params[:question_idurl])
    @question.link_back
    @products_distribution = @question.distribution_avg_weight
  end




end
