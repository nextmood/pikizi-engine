
class HomeController < ApplicationController

  # GET /quizzes
  # return all available quizzes for all knowledges
  def quizzes
    @knowledge = Knowledge.load("cell_phones")
    @quizzes = @knowledge.quizzes    
  end

  # GET /start_quiz/:quizze_id
  # create a new quiz for the current user
  def start_quiz
    quizze = Quizze.find(params[:quizze_id])
    get_logged_user.create_quizze_instance(quizze)
    redirect_to "/my_quiz"
  end

  # GET /my_quiz
  # asking the next question for a given quiz
  def my_quiz
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @knowledge = @quizze.get_knowledge
    else
      redirect_to("/quizzes") # select a quizz first !
    end
  end

  # GET /my_results
  def my_results
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @knowledge = @quizze.get_knowledge
      @sorted_affinities = @quizze_instance.sorted_affinities
      @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@knowledge, @sorted_affinities)
    else
      redirect_to("/quizzes") # select a quizz first !
    end    
  end

  # POST /record_my_answer
  def record_my_answer
     knowledge = Knowledge.load(knowledge_idurl = params[:knowledge_idurl])
     quizze = Quizze.load(quizze_idurl = params[:quizze_idurl])
     question = Question.load(question_idurl = params[:question_idurl])
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     redirect_to("/my_quiz")
  end

  def my_product()
    product_idurl = params[:product_idurl]
    @product = Product.load(product_idurl)
    @knowledge = Knowledge.load("cell_phones")    
  end

  # GET /product/:product_idurl
  def product
    product_idurl = params[:product_idurl]
    @product = Product.load(product_idurl)
    @knowledge = Knowledge.load("cell_phones")
  end

  # GET /products_search
  # POST /products_search
  def products_search
    @knowledge = Knowledge.load("cell_phones")
    search_string = params[:search_string]
    hash_category_products = @knowledge.products.group_by {|product| product.get_value("phone_category") }
    @list_category_products = hash_category_products.collect { |categories, products| [categories.join(', '), products] }
    @last_category = @list_category_products.last.first
    @knowledge = Knowledge.load("cell_phones")
    @quizzes = @knowledge.quizzes
  end

end
