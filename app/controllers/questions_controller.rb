
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

  def get_product_selected(params)
    @knowledge = Knowledge.load(params[:knowledge_idurl])
    @products = @knowledge.products
    @products_idurls = @products.collect(&:idurl)
    @pidurls_selected = params[:select_product_idurls]
    @pidurls_selected ||= session[:pidurls_selected]
    @pidurls_selected ||= @products_idurls
    session[:pidurls_selected] = @pidurls_selected
    @products_selected = @products.select { |p| @pidurls_selected.include?(p.idurl) }
  end


end
