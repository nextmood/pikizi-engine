
class HomeController < ApplicationController

  # GET /quizzes
  # return all available quizzes for all knowledges
  def quizzes
    @quizzes = @current_knowledge.quizzes
  end

  # GET /start_quizze/:quizze_id
  # create a new quiz for the current user
  def start_quizze
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
    else
      redirect_to("/quizzes") # select a quizz first !
    end
  end

  # GET /my_results
  def my_results
    @current_user = get_logged_user
    if @quizze_instance = @current_user.get_latest_quizze_instance
      @quizze = @quizze_instance.get_quizze
      @sorted_affinities = @quizze_instance.sorted_affinities
      @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@current_knowledge, @sorted_affinities)
    else
      redirect_to("/quizzes") # select a quizz first !
    end    
  end

  # POST /record_my_answer
  def record_my_answer
     knowledge = Knowledge.load_db(knowledge_idurl = params[:knowledge_idurl])
     quizze = Quizze.load_db(quizze_idurl = params[:quizze_idurl])
     question = Question.load_db(question_idurl = params[:question_idurl])
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     redirect_to("/my_quiz")
  end

  def my_product()
    if @quizze_instance = get_logged_user.get_latest_quizze_instance
      product_idurl = params[:product_idurl]
      @product = Product.load_db(product_idurl)
      @quizze = @quizze_instance.get_quizze
      @sorted_affinities = @quizze_instance.sorted_affinities
      @explanations, @hash_dimension2answers, @hash_question_idurl2min_max_weight = @quizze_instance.get_explanations(@current_knowledge, @sorted_affinities)
    else
      redirect_to("/quizzes") # select a quizz first !
    end

  end

  # GET /product/:product_idurl
  def product
    product_idurl = params[:product_idurl]
    @product = Product.load_db(product_idurl)
  end

  # GET /products_search
  # POST /products_search
  def products_search
    if @search_string = (params["s"] == Product.default_search_text ? nil : params["s"])
      if @search_string.has_prefix(prefix = "c=")
        @threshold_confidence = Float(@search_string.remove_prefix(prefix))
        @search_string = nil
      end
    end
    @threshold_confidence ||= 50.0
    

    products_found = @current_knowledge.products.select { |p| p.match_search(@search_string) }.first(20)
    @nb_results = products_found.size
    if products_found.size > 0
      hash_category_products = products_found.group_by {|product| product.get_value("phone_category") || ["unknown"]}
      @list_category_products = hash_category_products.collect { |categories, products| [categories.join(', '), products] }
      @last_category = @list_category_products.last.first
    else

    end
    @quizzes = @current_knowledge.quizzes

  end

  # this is rjs
  def switch_product_tab
    knowledge =  Knowledge.load_db(params[:knowledge_idurl])
    product = Product.load_db(params[:product_idurl])
    selected_key = params[:new_tab]
    render :update do |page|
      page.replace("product_tabs", :partial => "/home/product_tabs", 
                  :locals => { :selected_key => selected_key, :product => product })
    end
  end

  def ranking_by_dimension
    @dimension = Dimension.first(:idurl => params[:dimension_idurl])

    sorted_products_rating = @current_knowledge.products.inject([]) { |l, product| (x = product.get_dimension_value(@dimension.idurl)) ? l << [product, x] : l }
    sorted_products_rating.sort! { |p1, p2| p2.last <=> p1.last }

    previous_rating = nil; current_ranking = 0
    @sorted_products_ranking = sorted_products_rating.collect do |product, rating|
      current_ranking += 1 unless previous_rating == rating
      previous_rating = rating
      [product, current_ranking]
    end
  end

end
