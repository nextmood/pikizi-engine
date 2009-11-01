
class QuestionsController < ApplicationController
  

  # GET /questions/knowledge_idurl
  def index
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @products = @knowledge.products
  end

  # GET /questions/knowledge_idurl/question_idurl
  def show
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @question = @knowledge.get_question_by_idurl(params[:question_idurl])
    @hash_product_proba = @question.enumerator
    @products = @knowledge.products
  end


end




