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
     user = get_logged_pkz_user
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



  
  # GET /users/1/process_authored
  def process_authored
    @user = User.find(params[:id])
    message_processing = @user.pkz_user.process_authored
    flash[:notice] = "User was successfully processed. #{message_processing}"
    redirect_to(@user)
  end

  # GET /users/update_indexes
  # update the user database
  def update_indexes
    User.delete_all
    Pikizi::User.xml_keys.each do |user_key|
      pkz_user = Pikizi::User.create_from_xml(user_key)
      user = User.create(
              :key => user_key,
              :nb_quiz_instances => pkz_user.nb_quiz_instances,
              :nb_authored_opinions => pkz_user.nb_authored_opinions,
              :nb_authored_backgrounds => pkz_user.nb_authored_backgrounds,
              :nb_authored_values => pkz_user.nb_authored_values)
    end
    redirect_to("/users")
  end

    # this method is call back for rpxnow (this is triggered after login)
  # user_data
  # found: {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  # not found: nil (can happen with e.g. invalid tokens)
  def rpx_token_sessions_url
    raise "hackers?" unless rpx_data = RPXNow.user_data(params[:token])
    logged_user = User.find_by_rpx_identifier(rpx_data[:identifier])
    logged_user ||= User.create(:rpx_identifier => rpx_data[:identifier],
                                :rpx_name => rpx_data[:name],
                                :rpx_username => rpx_data[:username],
                                :rpx_email => rpx_data[:email])
    session[:logged_user_id] = logged_user.id
    # self.current_user = User.find_by_identifier(data[:identifier]) || User.create!(data)
    redirect_to '/'
  end

end
