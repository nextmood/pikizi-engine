# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.




class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :user_authorized, :except => ['login', 'rpx_token_sessions_url', 'access_restricted']


  # get the current logged user, the active record object
  def get_logged_ar_user()
    if session[:logged_user_rpx_identifier]
      begin
        @current_ar_user ||= User.find_by_rpx_identifier(session[:logged_user_rpx_identifier])
      rescue
        logger.error "Oups I'can't find user with id=#{session[:logged_user_rpx_identifier].inspect}"
        nil
      end
    end
  end


  def self.release_version() "v 3.0 alpha 09/13/09"  end

  private

  def user_authorized
    #if ENV['RAILS_ENV']=="production"
    if get_logged_ar_user
      # there is an existing logged user
      redirect_to '/access_restricted' unless get_logged_ar_user.is_authorized?
    else
      if ENV['RAILS_ENV'] == "development"
        log_as_developper
      else
        redirect_to '/login'
      end
    end
  end

  def log_as_developper
    developper_rpx_identifier = "#001"
    @current_ar_user = User.find_by_rpx_identifier(developper_rpx_identifier)
    @current_ar_user ||= User.create({ :rpx_identifier => developper_rpx_identifier,
                                       :rpx_name => "Franck Patte",
                                       :rpx_username => "fpatte",
                                       :rpx_email => "info@nextmood.com"})
    session[:logged_user_rpx_identifier] = @current_ar_user.id
  end



end
