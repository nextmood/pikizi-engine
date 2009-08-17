## controller to get AuthLogic and RPXNow.com working together
## see http://groups.google.com/group/authlogic/t/da0fa88c81799154

# Realm pikizi
# API Key (keep secret) 2dde4557bd28343f445032c774264a0b8cd8b29a
# Token URL Domains 88.191.47.17, localhost 

class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def rpx_create
    data = RPXNow.user_data(params[:token],'2dde4557bd28343f445032c774264a0b8cd8b29a')
    if data.blank?
      failed_login "Authentication failed."
    else
      @user = User.find_or_initialize_by_identity_url(data[:identifier])
      if @user.new_record?
        @user.display_name = data[:name] || data[:displayName] || data[:nickName]
        @user.email = data[:email] || data[:verifiedEmail]
        @user.save
      end
      UserSession.create(@user)
      successful_login
    end
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      successful_login
    else
      failed_login
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end


  protected


  def failed_login(message = nil)
    flash[:error] = message
    render :action => 'new'
  end

  def successful_login
    flash[:notice] = "Login successful!"
    redirect_back_or_default account_url
  end

end
