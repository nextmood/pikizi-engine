
class QuestionsController < ApplicationController
  

  # GET /questions/knowledge_idurl
  def index
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @products = @knowledge.products
    @products_idurls = @products.collect(&:idurl)
  end

  # GET /questions/knowledge_idurl/question_idurl
  def show
    @knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
    @question = @knowledge.get_question_by_idurl(params[:question_idurl])
    @products_distribution = @question.products_distribution
    @products = @knowledge.products
    @products_idurls = @products.collect(&:idurl)
  end




end
