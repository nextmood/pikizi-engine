class UsersController < ApplicationController
  # GET /users
  # GET /users.xml
  def index
    @users = User.all
    # get all quizzes from all models
    #@quizzes = Knowledge.find(:all).collect { |k| k.pkz_knowledge.quizzes }.flatten
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # POST /answer
  # POST /answer
  def record_answer
     knowledge_idurl = params[:knowledge_idurl]
     knowledge = Knowledge.get_from_idurl(params[:knowledge_idurl])
     quiz_idurl = params[:quiz_idurl] || knowledge_idurl
     quiz = knowledge.quizzes.detect {|q| q.idurl == quiz_idurl }
     question_idurl = params[:question_idurl]
     question = knowledge.questions.detect {|q| q.idurl == question_idurl }
     user = get_logged_ar_user.pkz_user
     user.record_answer(knowledge, quiz, question, params[:choices_idurls_ok])
     user.save
     url_redirect = "/quiz/#{knowledge.idurl}"
     url_redirect << "/#{quiz.idurl}" if knowledge.idurl != quiz.idurl
     redirect_to(url_redirect)
  end


  def show_by_rpx_identifier
    @user = User.find_by_rpx_identifier(params[:user_rpx_identifier])
    render(:action => 'show')
  end

  def toggle_promotion_code
    user_rpx_email = params[:user_rpx_email]
    user =  User.find_by_rpx_email(user_rpx_email)
    raise " no user with email #{user_rpx_email}" unless user
    case user.promotion_code
      when "none" then user.promotion_code = "auth"
      else user.promotion_code = "none"
    end
    user.save
    render :update do |page|
      page.replace_html("user_promotion_code_#{user_rpx_email}", user.promotion_code)
    end
  end


  def access_restricted
    get_logged_ar_user
  end


    # this method is call back for rpxnow (this is triggered after login)
  # user_data
  # found: {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  # not found: nil (can happen with e.g. invalid tokens)
  def rpx_token_sessions_url
    raise "hackers?" unless rpx_data = RPXNow.user_data(params[:token])
    rpx_identifier = rpx_data[:identifier]
    logged_user = User.find_by_rpx_identifier(rpx_identifier)

    # new user creation
    unless logged_user
      initial_attributes = {:rpx_identifier => rpx_identifier,
                            :rpx_name => rpx_data[:name],
                            :rpx_username => rpx_data[:username],
                            :rpx_email => rpx_data[:email] }
      initial_attributes[:promotion_code] = "auth" if rpx_data[:email] == "cpatte@gmail.com"
      logged_user = User.create(initial_attributes)
    end
    session[:logged_user_rpx_identifier] = rpx_identifier  unless session[:logged_user_rpx_identifier] == rpx_identifier

    if logged_user.is_authorized?    
      redirect_to '/'
    else
      redirect_to "/access_restricted"
    end

  end

  def logout
    session.delete(:logged_user_rpx_identifier)
  end
  
end
