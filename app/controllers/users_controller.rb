class UsersController < ApplicationController
  # GET /users
  # GET /users.xml
  def index
    @users = User.all
    # get all quizzes from all models
    @quizzes = Knowledge.find(:all).collect { |k| k.pkz_knowledge.quizzes }.flatten
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # POST /answer
  # POST /answer
  def record_answer
     knowledge_key = params[:knowledge_key]
     knowledge = Pikizi::Knowledge.get_from_cache(params[:knowledge_key])
     quiz_key = params[:quiz_key] || knowledge_key
     quiz = knowledge.quizzes.detect {|q| q.key == quiz_key }
     question_key = params[:question_key]
     question = knowledge.questions.detect {|q| q.key == question_key }
     user = get_logged_ar_user.pkz_user
     user.record_answer(knowledge, quiz, question, params[:choices_keys_ok])
     user.save
     url_redirect = "/quiz/#{knowledge.key}"
     url_redirect << "/#{quiz.key}" if knowledge.key != quiz.key
     redirect_to(url_redirect)
  end


  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])

    respond_to do |format|
      format.html # show_by_key.html.erb
      format.xml  { render :xml => @user }
    end
  end

  def show_by_key
    @user = User.find_by_key(params[:user_key])
    render(:action => 'show')
  end

  
  # GET /users/1/process_opinion
  def process_opinion
    @user = User.find(params[:id])
    message_processing = @user.pkz_user.process_opinion
    flash[:notice] = "User was successfully processed. #{message_processing}"
    redirect_to(@user)
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
    logged_user = User.find(:first, :conditions => ["rpx_identifier=?", rpx_data[:identifier]])
    logged_user ||= User.create_from_key(rpx_data)
    session[:logged_user_id] = logged_user.id

    if logged_user.is_authorized?    
      redirect_to '/'
    else
      redirect_to "/access_restricted"
    end

  end

  def logout
    session.delete(:logged_user_id)
  end
  
end
