class UsersController < ApplicationController
  
   skip_before_filter :check_user_authorization, :only => ['rpx_token_sessions_url', 'access_restricted', 'login']

  # GET /users
  def index
    @users = User.all
  end

  # POST /answer
  def record_answer
     knowledge = Knowledge.first(:idurl => (knowledge_idurl = params[:knowledge_idurl]))
     quizze = Quizze.first(:idurl => (quizze_idurl = params[:quizze_idurl]))
     question = Question.first(:idurl => (question_idurl = params[:question_idurl]))
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     url_redirect = "/myquizze/#{knowledge.idurl}"
     url_redirect << "/#{quizze.idurl}" if knowledge.idurl != quizze.idurl
     redirect_to(url_redirect)
  end

  def end_quizze
    quizze = Quizze.first(:idurl => params[:quizze_idurl])
    user = get_logged_user
    quizze_instance = QuizzeInstance.get_latest_for_quizze(quizze, user)
    raise "no quizze for feedack" unless quizze_instance
    if feedback_product_idurls_ok = params[:feedback_product_idurls_ok]      
      quizze_instance.affinities.each do |affinity|
        affinity.feedback = 1 if feedback_product_idurls_ok.include?(affinity.product_idurl)
      end
    end
    quizze_instance.closed_at = Time.now
    user.save
    knowledge_idurl = params[:knowledge_idurl]
    redirect_to("/quizzes/#{params[:knowledge_idurl]}")
  end

  def show_by_idurl
    @user = User.first(:idurl => params[:user_idurl])
    render(:action => 'show')
  end

  def toggle_role
    user_idurl = params[:user_idurl]
    user =  User.first(:idurl => user_idurl)
    raise " no user  #{user_idurl}" unless user
    case user.role
      when "unauthorised" then user.role = "tester"
      else user.role = "unauthorised"
    end
    user.save
    render :update do |page|
      page.replace_html("user_role_#{user.idurl}", user.role)
    end
  end

  def access_restricted
    get_logged_user
    session.delete(:logged_user_id)
  end

  # this method is call back for rpxnow (this is triggered after login)
  # user_data
  # found: {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  # not found: nil (can happen with e.g. invalid tokens)
  def rpx_token_sessions_url
    begin
      raise "hackers?" unless rpx_data = RPXNow.user_data(params[:token])

      rpx_email = rpx_data[:email]
      rpx_identifier = rpx_data[:identifier]
      user_idurl = User.compute_idurl(rpx_email, rpx_identifier)

      logged_user = User.first(:idurl => user_idurl)

      # new user creation
      is_new_user = false
      unless logged_user
        is_new_user = true
        logged_user = User.first_create(:rpx_identifier => rpx_identifier,
                            :rpx_name => rpx_data[:name],
                            :rpx_username => rpx_data[:username],
                            :rpx_email => rpx_email,
                            :role => ("admin" if rpx_email == "cpatte@gmail.com") )
      end

      if logged_user.is_authorized
        session[:logged_user_id] ||= logged_user.id
        redirect_to '/home'
      else
        redirect_to "/thanks/#{logged_user.id}/#{is_new_user}"
      end
    rescue
      redirect_to '/'  
    end

  end

  def logout
    session.delete(:logged_user_id)
  end

  def login

  end

  # update selection of products for current_user
  def update_selection
    session[:product_ids_selected] = params[:product_ids_selected].collect { |pid_select| BSON::ObjectID.from_string(pid_select) }
    puts "helo >>>>>>>>>>>>>> #{params[:product_ids_selected].inspect}"
    redirect_to(params[:url_redirect])
  end
  
end
