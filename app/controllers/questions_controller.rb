
class QuestionsController < ApplicationController
  

  # GET /questions/knowledge_idurl
  def index
    get_product_selected(params)
  end


  def update_weight
    question = Question.load(params[:question_idurl])
    question.weight +=  params[:delta]
    question.save
    redirect_to("/questions/#{params[:knowledge_idurl]}")
  end

  # GET /questions/knowledge_idurl/question_idurl
  def show
    get_product_selected(params)
    @question = @knowledge.get_question_by_idurl(params[:question_idurl])
    @products_distribution = @question.distribution_avg_weight
  end




end
