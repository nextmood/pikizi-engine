class UsersController < ApplicationController
  
   skip_before_filter :check_user_authorization, :only => ['rpx_token_sessions_url', 'access_restricted', 'login']

  # GET /users
  def index
    @users = User.all
  end

  # POST /answer
  def record_answer
     knowledge = Knowledge.get_from_idurl(knowledge_idurl = params[:knowledge_idurl])
     quizze = Quizze.get_from_idurl(quizze_idurl = params[:quizze_idurl])
     question = Question.get_from_idurl(question_idurl = params[:question_idurl])
     user = get_logged_user
     user.record_answer(knowledge, quizze, question, params[:choices_idurls_ok])
     user.save
     url_redirect = "/myquizze/#{knowledge.idurl}"
     url_redirect << "/#{quizze.idurl}" if knowledge.idurl != quizze.idurl
     redirect_to(url_redirect)
  end

  def show_by_idurl
    @user = User.get_from_idurl(params[:user_idurl])
    render(:action => 'show')
  end

  def toggle_role
    user_idurl = params[:user_idurl]
    user =  User.get_from_idurl(user_idurl)
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
    session.delete(:logged_user_idurl)
  end

  # this method is call back for rpxnow (this is triggered after login)
  # user_data
  # found: {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  # not found: nil (can happen with e.g. invalid tokens)
  def rpx_token_sessions_url
    raise "hackers?" unless rpx_data = RPXNow.user_data(params[:token])

    rpx_email = rpx_data[:email]
    rpx_identifier = rpx_data[:identifier]
    user_idurl = Digest::MD5.hexdigest(rpx_identifier)
    
    logged_user = User.get_from_idurl(user_idurl)

    # new user creation
    unless logged_user
      initial_attributes = {:idurl => user_idurl,
                            :rpx_identifier => rpx_identifier,
                            :rpx_name => rpx_data[:name],
                            :rpx_username => rpx_data[:username],
                            :rpx_email => rpx_email }
      initial_attributes[:role] = "admin" if rpx_email == "cpatte@gmail.com"
      logged_user = User.create(initial_attributes)
      logged_user.link_back(nil)
    end
    session[:logged_user_idurl] |= user_idurl

    if logged_user.is_authorized
      redirect_to '/'
    else
      redirect_to "/access_restricted"
    end

  end

  def logout
    session.delete(:logged_user_idurl)
  end

  def login

  end
end
